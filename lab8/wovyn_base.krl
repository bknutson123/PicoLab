ruleset wovyn_base {
  meta {
    use module io.picolabs.lesson_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module sensor_profile
    use module temperature_store
    logging on
  }
  
  global {
    from_number = "+17125878816"
  }
  
  rule create_temperature_report {
    select when report create_report
    event:send(
      { "eci": event:attr("Rx"), "eid": "reportFinished",
            "domain": "report", "type": "recieved",
            "attrs": {
              "correlation_id": event:attr("correlation_id"),
              "temperatures": temperature_store:temperatures(),
              "Tx": event:attr("Tx")
            } }
            )
  }
  
  rule process_heartbeat {
    select when get heartbeat where genericThing
    pre {
      test = event:attr("genericThing"){"data"}{"temperature"}.klog()
      test2 = event:attr("genericThing"){"data"}{"temperature"}{0}.klog()
      temperature = event:attr("genericThing"){"data"}{"temperature"}{0}{"temperatureF"}.klog()
    }

    send_directive("heartbeat!!");
    
    fired {
      raise wovyn event "new_temperature_reading" attributes { 
        "temperature": temperature,
        "timestamp": time:now()
      }
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature").klog("This is the temperature: ")
    }
    
    if temp > sensor_profile:profile(){"threshold_temperature"}.as("Number").klog("TEMP THRES FROM SES PROFILE") then
      send_directive("Temperature threshold reached!")  
      
    fired {
      raise wovyn event "threshold_violation" attributes event:attrs
    }
  }
  
  rule accept_all_subscriptions {
        select when wrangler inbound_pending_subscription_added
        fired {
            raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        }
    }
  
  rule send_threshold_notification {
    select when wovyn threshold_violation
    foreach Subscriptions:established("Rx_role", "sensor_controller") setting (subscription)
      event:send({
        "eci": subscription{"Tx"}, 
        "eid": "threshold-violation",
        "domain": "sensor_manager",
        "type": "violation",
        "attrs": event:attrs
      })
  }
}
