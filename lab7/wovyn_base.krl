ruleset manage_sensors {
  
  meta {
      shares get_all_temperatures, sensors, reports
      use module io.picolabs.subscription alias Subscriptions
      use module management_profile
  }
  
  global {
    nameFromID = function(sensor_id) {
      "Sensor " + sensor_id + " Pico"
    }
    threshold = 75.4
    phone_number = "+8016366490"
    location = "location"
    
    sensors = function() {
      Subscriptions:established("Rx_role", "sensor_controller")
    }
    
    get_all_temperatures = function() {
      test = sensors().klog()
      sensors().map(function(v,k) {
        test = v{"Tx"}.klog()
        test2 = k.klog()
        http:get("http://localhost:8080/sky/cloud/" + v{"Tx"} + "/temperature_store/temperatures"){"content"}.decode().klog()
      })
      
    }
        
    reports = function() {
      ent:reports.defaultsTo([]).reverse().slice(4).klog()
    }
  }
  
  rule start_report {
    select when report start
    pre {
      correlation_id = random:uuid
    }
    always {
      ent:processingReports := ent:processingReports.defaultsTo({});
      ent:processingReports{correlation_id} := {"temperature_sensors": sensors().length(), "temperatures": []}
      raise report event "send" attributes {"correlation_id": correlation_id}
    }
  }
  
  rule send_report {
    select when report send
    foreach sensors() setting(s)
    event:send({ "eci": s{"Tx"}, "eid": "reportStart",
            "domain": "report", "type": "create_report",
            "attrs": {"Rx": s{"Rx"}, "Tx": s{"Tx"}, "correlation_id": event:attr("correlation_id")} }
            )
  }
  
  rule recieve_report {
    select when report recieved
    pre {
      correlation_id = event:attr("correlation_id")
      temperatures = event:attr("temperatures")
      tx = event:attr("Tx")
      current_report = ent:processingReports{correlation_id}
      tempsList = current_report{"temperatures"}.append({"Tx": tx, "temperatures": temperatures})
    }
    // If the number of temperatures has not changed since the last time a report was recieved then dont add to ent:reports
    if (current_report["temperature_sensors"] == tempsList.length()) then noop()
    
    fired {
      ent:processingReports := ent:processingReports.put([correlation_id], {"temperature_sensors": current_report["temperature_sensors"], "temperatures": tempsList}).klog()
      // ent:processingReports{correlation_id} := {"temperature_sensors": current_report["temperature_sensors"], "temperatures": tempsList}
      report = ent:processingReports{correlation_id}
      ent:reports := ent:reports.defaultsTo([]).append({
                "temperature_sensors": report{"temperature_sensors"},
                "number_of_sensors_responding": report{"temperatures"}.length(),
                "temperatures": report{"temperatures"}
            })
    } else {
      // ent:processingReports{correlation_id} := {"temperature_sensors": current_report["temperature_sensors"], "temperatures": tempsList}
      ent:processingReports := ent:processingReports.put([correlation_id], {"temperature_sensors": current_report["temperature_sensors"], "temperatures": tempsList}).klog()
    }
  }
  
  rule subscription_added {
        select when wrangler subscription_added
        pre {
            Tx = event:attr("_Tx").klog("tx is: ")
        }
    }
  
  rule create_and_setup_pico {
    select when sensor new_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:all_sensors >< nameFromID(sensor_id)
    }
    
    if exists then
      send_directive("sensor_ready", {"sensor already created":sensor_id})

    notfired {
      raise wrangler event "child_creation"
        attributes { "name": nameFromID(sensor_id), "color": "#ffff00", "rids": ["io.picolabs.subscription", "temperature_store", "sensor_profile", "wovyn_base"]}
    }
  }
  
  rule save_name_to_eci_sensor {
    select when wrangler new_child_created
    
    pre {
      name = event:attr("name")
      id = event:attr("id")
      eci = event:attr("eci")
    }
    
    event:send({ "eci"   : eci,
             "domain": "sensor", "type": "profile_updated",
             "attrs" : { "name": name, "threshold_temperature": threshold, "phone_number": phone_number, "location": location }, "eid": "" })

    always {
      ent:all_sensors := ent:all_sensors.defaultsTo({})
      ent:all_sensors{[name]} := {"id": id, "eci": eci}
      raise wrangler event "subscription" attributes
       { "name" : "my_sensor",
         "Rx_role": "sensor_controller",
         "Tx_role": "sensor_thing",
         "channel_type": "subscription",
         "wellKnown_Tx" : eci
       }
    }
  }
  
  rule introduce_sensor_to_manager {
        select when sensor introduce
        pre {
            name = event:attr("name")
            eci = event:attr("eci")
            host = event:attr("host")
        }

        always {
            raise wrangler event "subscription" attributes
                {
                    "name": name,
                    "Rx_role": "sensor_controller",
                    "Tx_host": host,
                    "Tx_role": "sensor_thing",
                    "channel_type": "subscription",
                    "wellKnown_Tx": eci
                }
        }
    }
    
  rule send_violation_message {
        select when sensor_manager violation
        pre {
            notification_message = "violation: " + event:attr("temperature") + " at this time: " + event:attr("timestamp")
        }
        always{
            raise management_profile event "send_sms"
                attributes {"notification_message": notification_message}
        }
    }
  
  rule unneeded_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
      sensor_to_delete = ent:all_sensors{name}
    }
    
    fired {
      raise wrangler event "child_deletion" attributes sensor_to_delete
      ent:all_sensors := ent:all_sensors.delete([name])
    }
  }
  
}
