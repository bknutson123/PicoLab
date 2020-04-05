ruleset management_profile {
  
  meta {
    use module io.picolabs.lesson_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module sensor_profile
    logging on
  }
  
  global {
    from_phone_number = "+17125878816"
    location = "location"
  }
  
  rule update_profile {
    select when sensor profile_updated
    pre {
      new_number = event:attr("new_number").defaultsTo(ent:number)
    }
    
    always {
      ent:number := new_number
    }
  }
  
  rule setup {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      ent:number := "+8016366490"
    }
  }
  
  rule send_sms {
    select when management_profile send_sms
    pre {
      notification_message = event:attr("notification_message")
      send_to = ent:number
    }
    twilio:send(send_to, from_phone_number, notification_message)
  }
}
