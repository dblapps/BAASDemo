Parse.Cloud.afterSave("Notes", function(request) {
  var pushQuery = new Parse.Query(Parse.Installation);
  pushQuery.equalTo('deviceType', 'ios');
  Parse.Push.send({
    where: pushQuery, // Set our Installation query
    data: {
      "badge": "0",
      "content-available": 1,
      "n": {
        "t": request.object.existed() ? "upd" : "add",
        "id": request.object.id
      }
    }
  }, {
    success: function() {
      // Push was successful
    },
    error: function(error) {
      throw "Got an error " + error.code + " : " + error.message;
    }
  });
});

Parse.Cloud.afterDelete("Notes", function(request) {
  var pushQuery = new Parse.Query(Parse.Installation);
  pushQuery.equalTo('deviceType', 'ios');
  Parse.Push.send({
    where: pushQuery, // Set our Installation query
    data: {
      "badge": "0",
      "content-available": 1,
      "n": {
        "t": "del",
        "id": request.object.id
      }
    }
  }, {
    success: function() {
      // Push was successful
    },
    error: function(error) {
      throw "Got an error " + error.code + " : " + error.message;
    }
  });
});

