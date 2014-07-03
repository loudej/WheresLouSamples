
jQuery(function ($) {

    $.ajax("/serverName").done(function (data)
    {
        $("#serverName").text(data);
    });

    var ws = new WebSocket("ws://localhost:5000/serverTime");

    ws.onopen = function (evt) {
        setInterval(function () {
            ws.send("");
        }, 300);
    };

    ws.onmessage = function (evt) {
        $("#serverTime").text(evt.data);
    };
});
