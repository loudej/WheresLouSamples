using System;
using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNet.Builder;
using Microsoft.AspNet.Http;

public class Startup 
{
    public void Configure(IBuilder app)
    {
        // inline middleware via Use
        var requestCount = 0;
        app.Use(next => async context =>
        {
            var sw = new Stopwatch();
            sw.Start();
            var requestNumber = Interlocked.Increment(
                ref requestCount);

            // request is incoming
            Console.WriteLine(string.Format(
                "1st #{0} incoming {1} {2}{3}{4}", 
                requestNumber,
                context.Request.Method,
                context.Request.PathBase,
                context.Request.Path,
                context.Request.QueryString));

            // pass control to following components
            await next(context);

            // call is unwinding
            Console.WriteLine(string.Format(
                "1st #{0} outgoing {1} {2}ms", 
                requestNumber,
                context.Response.StatusCode,
                sw.ElapsedMilliseconds));
        });

        // middleware class via use
        app.Use(next => new LogRequestsMiddleware(next, "2nd").Invoke);

        // middleware class via extension method
        app.UseLogRequests("3rd");

        // finally, respond to all requests in the same way
        app.Run(async context =>
        {
            context.Response.ContentType = "text/plain";
            await context.Response.WriteAsync("Hello World!");        
        });
    }
}

public static class LogRequestsExtensions
{
    public static IBuilder UseLogRequests(this IBuilder app, string label)
    {
        // additional arguments are passed to constructor
        return app.UseMiddleware<LogRequestsMiddleware>(label);
    }
}

public class LogRequestsMiddleware
{
    RequestDelegate _next;
    int _requestCount;
    string _label;

    // called once when pipeline is built
    public LogRequestsMiddleware(RequestDelegate next, string label)
    {
        _next = next;
        _label = label;
    }

    // called once per request
    public async Task Invoke(HttpContext context)
    {
        var sw = new Stopwatch();
        sw.Start();
        var requestNumber = Interlocked.Increment(
            ref _requestCount);

        // request is incoming
        Console.WriteLine(string.Format(
            "{0} #{1} incoming {2} {3}{4}{5}", 
            _label,
            requestNumber,
            context.Request.Method,
            context.Request.PathBase,
            context.Request.Path,
            context.Request.QueryString));

        // pass control to following components
        await _next(context);

        // call is unwinding
        Console.WriteLine(string.Format(
            "{0} #{1} outgoing {2} {3}ms", 
            _label,
            requestNumber,
            context.Response.StatusCode,
            sw.ElapsedMilliseconds));
    }
}
