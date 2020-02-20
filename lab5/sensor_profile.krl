ruleset sensor_profile {
  
  meta {
      provides profile
      shares profile
  }
  
  global {
    profile = function() {
      { "location": ent:location.defaultsTo("location"),
        "name": ent:name.defaultsTo("name"),
        "notification_number": ent:phone_number.defaultsTo("+18016366490"),
        "threshold_temperature": ent:threshold_temperature.defaultsTo(70)
      }
    }
  }
  
  rule update_profile {
    select when sensor profile_updated
    pre {
      name = event:attr("name").defaultsTo(ent:name).klog("update_profile name: ")
      location = event:attr("location").defaultsTo(ent:location).klog("update_profile location: ")
      phone_number = event:attr("phone_number").defaultsTo(ent:phone_number).klog("update_profile phone_number: ")
      threshold_temperature = event:attr("threshold_temperature").defaultsTo(ent:threshold_temperature).klog("update_profile threshold_temperature: ")
    }

    always{
      ent:name := name
      ent:location := location
      ent:phone_number := phone_number
      ent:threshold_temperature := threshold_temperature
    }
  }
}
