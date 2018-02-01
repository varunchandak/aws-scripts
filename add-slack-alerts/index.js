console.log('Loading function');

const https = require('https');
const url = require('url');
const slack_url = 'ENTER_WEBHOOK_HERE';
const slack_req_opts = url.parse(slack_url);
slack_req_opts.method = 'POST';
slack_req_opts.headers = {
    'Content-Type': 'application/json'
};

exports.handler = function(event, context) {
    (event.Records || []).forEach(function(rec) {
        if (rec.Sns) {
            var req = https.request(slack_req_opts, function(res) {
                if (res.statusCode === 200) {
                    context.succeed('posted to slack');
                } else {
                    context.fail('status code: ' + res.statusCode);
                }
            });

            req.on('error', function(e) {
                console.log('problem with request: ' + e.message);
                context.fail(e.message);
            });
            
            var text_msg = JSON.stringify(rec.Sns.Message, null, '  ');
            try {
                var msg_data = [];
                var parsed = JSON.parse(rec.Sns.Message);
                console.log("SNS Message:",parsed);
                // for (var key in parsed) {
                //     msg_data.push(key + ': ' + parsed[key]);
                // }
                msg_data.push("Alarm Name"+": "+parsed['AlarmName']);
                msg_data.push("Metric Name"+": "+parsed['Trigger']['MetricName']);
                var dimensions = parsed['Trigger']['Dimensions'];
                for(var i=0;i<dimensions.length;i++){
                    msg_data.push(dimensions[i].name+": "+dimensions[i].value);
                }
                text_msg = msg_data.join("\n");
            } catch (e) {
                console.log(e);
            }

            var params = {
                attachments: [{
                    fallback: text_msg,
                    pretext: rec.Sns.Subject,
                    color: "#D00000",
                    fields: [{
                        "value": text_msg,
                        "short": false
                    }]
                }]
            };
            req.write(JSON.stringify(params));

            req.end();
        }
    });
};
