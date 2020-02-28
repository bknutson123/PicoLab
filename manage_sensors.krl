ruleset manage_sensors {
  
  meta {
      provides get_all_temperatures, sensors
      shares get_all_temperatures, sensors
  }
  
  global {
    nameFromID = function(sensor_id) {
      "Sensor " + sensor_id + " Pico"
    }
    threshold = 75.4
    phone_number = "+8016366490"
    location = "location"
    
    sensors = function() {
      return ent:all_sensors
    }
    
    get_all_temperatures = function() {
      test = sensors().klog()
      sensors().map(function(v,k) {
        test = v{"eci"}.klog()
        test2 = k.klog()
        http:get("http://localhost:8080/sky/cloud/" + v{"eci"} + "/temperature_store/temperatures"){"content"}.decode().klog()
      })
      
    }
  }
  
  rule create_and_setup_pico {
    select when sensor new_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:all_sensors >< nameFromID(sensor_id)
      eci = meta:eci
    }
    
    if exists then
      send_directive("sensor_ready", {"sensor already created":sensor_id})

    notfired {
      raise wrangler event "child_creation"
        attributes { "name": nameFromID(sensor_id), "color": "#ffff00", "rids": ["temperature_store", "sensor_profile", "wovyn_base"]}
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
    }
  }
  
  rule unneeded_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
      sensor_to_delete = ent:all_sensors{name}
    }
    
    fired {
      raise wrangler event "child_deletion" attributes sensor_to_delete;
      ent:all_sensors := ent:all_sensors.delete([name])
    }
  }
  
}
