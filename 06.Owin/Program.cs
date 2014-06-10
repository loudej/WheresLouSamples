using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNet.Builder;
using Nowin;

namespace MyApp
{
    using AppFunc = Func<IDictionary<string, object>, Task>;

    using MidFunc = Func<
          Func<IDictionary<string, object>, Task>,
          Func<IDictionary<string, object>, Task>
        >;

    using BuildFunc = Action<Func<
          Func<IDictionary<string, object>, Task>,
          Func<IDictionary<string, object>, Task>
        >>;

    public class Program  
    {
        static AppFunc notFound = async env => env["owin.ResponseStatusCode"] = 404;

        public void Main(string[] args) 
        {
            // List.Add is same signature as BuildFunc
            IList<MidFunc> list = new List<MidFunc>();
            Configure(list.Add);

            // Now chain middleware together in reverse order
            AppFunc app = list
                .Reverse()
                .Aggregate(notFound, (next, middleware) => middleware(next));

            // Finally start OWIN server
            var server = ServerBuilder.New().SetPort(5000).SetOwinApp(app);
            using (server.Start())
            {
                Console.WriteLine("Listening on port 5000. Enter to exit.");
                Console.ReadLine();
            }
        }

        public void Configure(BuildFunc build)
        {
            // OWIN middleware
            build.UseLogRequests("OWIN Middleware");

            // adding vNext component in OWIN pipline
            build.UseBuilder().Run(async context =>
            {
                Console.WriteLine("Returning Hello World");
                context.Response.ContentType = "text/plain";
                await context.Response.WriteAsync("Hello World!");        
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

            var responseStatusCode = (int)env["owin.ResponseStatusCode"];

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

