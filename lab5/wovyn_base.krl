ruleset wovyn_base {
  meta {
    use module io.picolabs.lesson_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module sensor_profile
    logging on
  }
  
  global {
    from_number = "+17125878816"
  }
  
  rule process_heartbeat {
    select when get heartbeat where genericThing

    send_directive("heartbeat!!");
    
    fired {
      raise wovyn event "new_temperature_reading" attributes { 
        "temperature": event:attr("genericThing"){"data"}{"temperature"}{0}{"temperatureF"},
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
  
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      var = "Made it into threshold".klog()
    }
     twilio:send_sms(sensor_profile:profile(){"notification_number"}.klog("NOTIFI NUM FROM SES PROFILE"),
                     from_number.klog(),
                     ("threshold temperature has been met!! This was the offending temperature: " + event:attr("temperature")).klog()
                   )
  }
}
