using System;
using System.Threading.Tasks;
using Microsoft.AspNet.Builder;
using Microsoft.AspNet.FileSystems;
using Microsoft.AspNet.Http;
using Microsoft.AspNet.StaticFiles;
using System.Threading;
using System.Net.WebSockets;
using System.Text;

namespace WheresLouSamples
{
    public class Startup
    {
        /* workaround the fact that mono and ms clr define this enum differently :( */
        static WebSocketMessageType MessageType_Text = (WebSocketMessageType)0;
        static WebSocketMessageType MessageType_Binary = (WebSocketMessageType)1;
        static WebSocketMessageType MessageType_Close = (WebSocketMessageType)2;

        public void Configure(IBuilder app)
        {
            // serve static files from public subfolder
            app.UseFileServer(new FileServerOptions
            {
                FileSystem = new PhysicalFileSystem("public"),
                DefaultFilesOptions =
                {
                    DefaultFileNames = {"index.html" }
                }
            });

            // return server name from any "/serverName" paths
            var serverName = app.Server.Name;
            app.Map("/serverName", map => map.Run(async ctx =>
            {
                ctx.Response.ContentType = "text/plain";
                await ctx.Response.WriteAsync(serverName);
            }));

            // add WebSocket support when server only supports Upgrade
            app.UseWebSockets();

            // return server time from any "/serverTime" paths
            app.Map("/serverTime", map => map.Run(ServerTimeRequest));
        }

        public async Task ServerTimeRequest(HttpContext context)
        {
            var webSocket = await context.AcceptWebSocketAsync();

            var buffer = new ArraySegment<byte>(new byte[8192]);
            for(; ;)
            {
                // spin on receiving
                var result = await webSocket.ReceiveAsync(buffer, CancellationToken.None);
                if (result.MessageType == MessageType_Close)
                {
                    // break out when the client goes away
                    return;
                }

                if (result.EndOfMessage)
                {
                    // respond with the time each time a complete request has arrived
                    var nowText = DateTimeOffset.UtcNow.ToString();
                    var nowBytes = Encoding.UTF8.GetBytes(nowText);
                    await webSocket.SendAsync(
                        new ArraySegment<byte>(nowBytes),
                        MessageType_Text,
                        true,
                        CancellationToken.None);
                }
            }
        }
    }
}
