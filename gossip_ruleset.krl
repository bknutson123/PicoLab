ruleset gossip_ruleset {
  meta {
    use module io.picolabs.subscription alias Subscriptions
    shares getPeerState, getSystemStatus, listTemperatures, schedule, getMissingMessages
  }
  
  global {
    getPeer = function() {
      subscriptions = Subscriptions:established("Rx_role", "sensor_controller").klog("SUBSCRIPTIONS: ")
      subscription_id = random:integer(subscriptions.length() - 1)
      
      filteredPeers = ent:peerState.filter(function(k,v) {
        getMissingMessages(k).length() > 0
      })
      var = filteredPeers.klog("FILTERED: ")
      random = random:integer(filteredPeers.length() - 1)
      item = filteredPeers.keys()[random]
      subscriptions.filter(function(a) {
        a{"Tx"} == item
      })[0].isnull() => subscriptions[subscription_id] | subscriptions.filter(function(a){a{"Tx"} == item})[0]
    }
    
    getPeerState = function() {
      ent:peerState
    }
    
    
    prepareMessage = function(person) {
      (random:integer(1) == 0) => seenMessage().klog("SEEN MESSAGE: ") | rumorMessage(person) 
    }
    
    getSystemStatus = function() {
      ent:system_status
    }
    
    listTemperatures = function() {
      ent:seenMessages.filter(function(a) {
        id = a{"MessageID"}
        seqNum = getSequenceNum(id)
        picoId = getPicoID(id)
        ent:seen{picoId} == seqNum
      })
    }
    
    createMessageID = function() {
      <<#{meta:picoId}:#{ent:sequence}>>
    }
    
    createMessage = function(messageId, sensorId, temperature, time) {
      {
        "messageID": messageId,
        "SensorID": sensorId,
        "Temperature": temperature,
        "Timestamp": time
      }
    }
    
    getPicoID = function(id) {
      id.split(re#:#)[0]
    }
    
    getSequenceNum = function(id) {
      idArray = id.split(re#:#)
      idArray[idArray.length() - 1].as("Number")
    }
    
    getMissingMessages = function(seen) {
      ent:seenMessages.filter(function(a) {
        id = getPicoID(a{"MessageID"})
        seen{id}.isnull() || seen{id} < getSequenceNum(a{"MessageID"}) => true | false
      }).sort(function(seq1, seq2) {
        seqa = getSequenceNum(seq1{"MessageID"})
        seqb = getSequenceNum(seq2{"MessageID"})
        seqa < seqb => -1 |
        seqa == seqb => 0 | 1
      })
    }
    
    seenMessage = function() {
      {
        "message": ent:seen,
        "type": "seen"
      }
    }
    
    rumorMessage = function(person) {
      missingMessages = getMissingMessages(ent:peerState{person{"Tx"}}).klog("MISSING MESSAGES: ")
      ret = {
        "message": (missingMessages.length() == 0) => null | missingMessages[0],
        "type": "rumor"
      }
      ret
    }
    
    getHighestSequenceNum = function(picoId) {
      ent:seenMessages.filter(function(a) { getPicoID(a{"MessageID"}) == picoId }).map(function(a) { 
        getSequenceNum(a{"MessageID"})
        
      }).sort(function(seq1, seq2) {
        seq1 < seq2 => -1 | seq1 == seq2 => 0 | 1
      }).reduce(function(seq1, seq2) {
        seq2 == seq1 + 1 => seq2 | seq1
      }, -1)
    }
  }
  
  rule initalize_gossip {
    select when wrangler ruleset_added where rids >< meta:rid
    
    always {
      ent:time := 5.klog()
      ent:system_status := "on".klog()
      ent:sequence := 0;
      ent:seen := {};
      ent:peerState := {};
      ent:seenMessages := [];
      raise gossip event "schedule" attributes {"time": ent:time}
    }
  }
  
  // Sets a new time if one is passed in and schedules a gossip heartbeat
  rule gossip_schedule {
    select when gossip schedule 
    pre {
      schedule_time = event:attr("time").defaultsTo(ent:time)
    }
    always {
      ent:time := schedule_time
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": schedule_time})
    }
  }
  
  rule gossip_heartbeat {
    select when gossip heartbeat where ent:system_status == "on"
    pre {
      subscriber = getPeer().klog("THIS IS A TEST")
      message = prepareMessage(subscriber).klog("MESSAGE: ")
      attribute = {"subscriber": subscriber, "message": message{"message"}}
    }
    
    if (not subscriber.isnull()) && (not message{"message"}.isnull()) then noop()
    fired {
      raise gossip event "set_rumor" attributes attribute if (message{"type"} == "rumor")
      raise gossip event "set_seen" attributes attribute if (message{"type"} == "seen")
    }
  }
  
  rule set_message_as_seen {
    select when gossip set_seen
    pre {
      subscriber = event:attr("subscriber")
      message = event:attr("message")
      picoId = getPicoID(message{"MessageID"})

    }
       event:send(
            { "eci": subsriber{"Tx"}, "eid": "gossip_message",
                "domain": "gossip", "type": "seen",
                "attrs": {"message": message, "Rx": subscriber{"Rx"}}
            }
        ) 
  }
  
  rule gossip_save_seen {
        select when gossip seen where ent:process == "on"
        pre {
            rx = event:attr("Rx")
            message = event:attr("message")
        }

        always {
            ent:peerState{rx} := message
        }
    }
  
  //TODOZ:fix this up!!!!!
  rule gossip_seen_send_rumors {
        select when gossip seen where ent:process == "on"
        foreach getMissingMessages(event:attr("message")).klog("Missing:") setting(m)
        pre {
            rx = event:attr("Rx")
        }

        event:send(
            { "eci": rx, "eid": "gossip_message_response",
                "domain": "gossip", "type": "rumor",
                "attrs": m
            }
        )
    }
  
  rule set_message_as_rumor {
    select when gossip set_rumor
    pre {
      subscriber = event:attr("subscriber").klog("RUMOR SUBSCRIBER")
      message = event:attr("message").klog("RUMOR MESSAGE")
      picoId = getPicoID(message{"MessageID"})
      sequenceNumber = getSequenceNum(message{"MessageID"})
    }
      event:send(
        {
          "eci": subscriber{"Tx"},
          "eid": "gossip_message",
          "domain": "gossip",
          "type": "rumor",
          "attrs": message
        }  
      ) 
    always {
      ent:peerState{[subscriber{"Tx"}, picoId]} := sequenceNumber
      if (ent:peerState{subscriber{"Tx"}}{picoId} + 1 == sequenceNumber) || (ent:peerState{subscriber{"Tx"}}{picoId}.isnull() && sequenceNumber == 0)
    }
  }
  
  rule gossip_rumor {
    select when gossip rumor where ent:system_status == "on"
    pre {
      messageId = event:attr("MessageID")
      sequenceNumber = getSequenceNum(messageId)
      picoId = getPicoID(messageId)
      seen = ent:seen{picoId}
      first_seen = ent:seen{picoId}.isnull()
    }
    
    if first_seen then noop()
    fired {
      ent:seen{picoId} := -1
    } finally {
      ent:seenMessages := ent:seenMessages.append(createMessage(id, event:attr("SensorID"), event:attr("Temperature"), event:attr("Timestamp"))) if ent:seenMessages.filter(function(m) {m{"MessageID"} == messageId}).length == 0
      ent:seen{picoId} := getHighestSequenceNum(picoId)
    }
  }
  
  rule set_system_status {
    select when gossip process where status
    always {
      ent:system_status := event:attr("status")
    }
  }
  
  rule pending_subscription_added {
    select when wrangler inbound_pending_subscription_added
    if not event:attr("Tx").isnull() then noop()
    fired {
      raise wrangler event "pending_subscription_approval" attributes event:attrs
      ent:peerState{event:attr("Tx")} := {}
    }
  }
  
  rule subscription_added {
    select when wrangler subscription_added
    pre {
      tx = event:attr("_Tx")
    }
    if not tx.isnull() then noop()
    fired {
      ent:peerState{tx} := {}
    }
  }
  
  
  rule receive_temperature {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attr("temperature").klog("TEMPERATURE TEST")
      time = event:attr("timestamp").klog("TIMESTAMP TEST")
      message = createMessage(createMessageID(), meta:picoId, temperature, time).klog("MESSAGE TEST")
    }
    always {
      ent:seenMessages := ent:seenMessages.append(message)
      ent:sequence := ent:sequence + 1
      ent:seen{meta:picoId} := getHighestSequenceNum(meta:picoId)
    }
  }
}
  
  
