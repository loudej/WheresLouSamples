using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNet.Builder;

namespace MyApp
{
    using AppFunc = 
        Func<IDictionary<string, object>, Task>;

    using BuildFunc = Action<Func<
        Func<IDictionary<string, object>, Task>,
        Func<IDictionary<string, object>, Task>
    >>;

    public class Startup 
    {
        public void Configure(IBuilder app)
        {
            var build = app.UseOwin();

            // Example using a pure OWIN extension method
            build.UseLogRequests("OWIN Middleware");

            // Handle all requests by writing out request headers and OWIN environment 
            build(next => async env => {
                var requestHeaders = (IDictionary<string, string[]>)env["owin.RequestHeaders"];
                var responseHeaders = (IDictionary<string, string[]>)env["owin.ResponseHeaders"];

                var responseBody = (Stream)env["owin.ResponseBody"];

                using (var responseWriter = new StreamWriter(responseBody, Encoding.UTF8))
                {
                    responseHeaders["Content-Type"] = new[]{"text/plain"};

                    await responseWriter.WriteLineAsync("=== Request Headers ===");

                    foreach(var header in requestHeaders)
                    {
                        await responseWriter.WriteLineAsync(header.Key + ": " + String.Join(", ", header.Value));
                    }

                    await responseWriter.WriteLineAsync("");
                    await responseWriter.WriteLineAsync("=== OWIN Environment ===");

                    foreach(var entry in env)
                    {
                        await responseWriter.WriteLineAsync(entry.Key + ": " + String.Join(", ", entry.Value));
                    }

                }
            });
        }
    }

    public static class LogRequestsExtensions
    {
        public static BuildFunc UseLogRequests(this BuildFunc build, string label)
        {
            build(next => new LogRequestsMiddleware(next, label).Invoke);
            return build;
        }
    }

    public class LogRequestsMiddleware
    {
        AppFunc _next;
        int _requestCount;
        string _label;

        // called once when pipeline is built
        public LogRequestsMiddleware(AppFunc next, string label)
        {
            _next = next;
            _label = label;
        }

        // called once per request
        public async Task Invoke(IDictionary<string,object> env)
        {
            var sw = new Stopwatch();
            sw.Start();
            var requestNumber = Interlocked.Increment(
                ref _requestCount);

            // request is incoming
            var requestMethod = (string)env["owin.RequestMethod"];
            var requestPathBase = (string)env["owin.RequestPathBase"];
            var requestPath = (string)env["owin.RequestPath"];
            var requestQueryString = (string)env["owin.RequestQueryString"];

            Console.WriteLine(string.Format(
                "{0} #{1} incoming {2} {3}{4}{5}", 
                _label,
                requestNumber,
                requestMethod,
                requestPathBase,
                requestPath,
                requestQueryString));

            // pass control to following components
            await _next(env);

            var responseStatusCode = (string)env["owin.ResponseStatusCode"];

            // call is unwinding
            Console.WriteLine(string.Format(
                "{0} #{1} outgoing {2} {3}ms", 
                _label,
                requestNumber,
                responseStatusCode,
                sw.ElapsedMilliseconds));
        }
    }

}