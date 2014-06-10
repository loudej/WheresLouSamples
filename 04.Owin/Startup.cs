using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Microsoft.AspNet.Builder;

public class Startup 
{
    public void Configure(IBuilder app)
    {
        var build = app.UseOwin();

        build(next => async env => {
            // Get some OWIN keys from the environment
            var responseHeaders = (IDictionary<string, string[]>)env["owin.ResponseHeaders"];
            var responseBody = (Stream)env["owin.ResponseBody"];

            // Set the content type and write some data
            responseHeaders["Content-Type"] = new[]{"text/plain"};
            var data = Encoding.UTF8.GetBytes("Hello world!");
            await responseBody.WriteAsync(data, 0, data.Length);
        });
    }
}

public class 