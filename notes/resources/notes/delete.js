dpd.devices.get(function(result, error) {
    var devices = [];
    var length = result.length;
    for (var i = 0; i < length; i++) {
        var device = result[i];
        devices.push(device.apnToken);
    }
    dpd.apndev.post(
        {
            payload: {
                n: {
                    t: "del",
                    id: this.id
                }
            },
            devices: devices
        },
        function(result, err) {
        }
    );
});