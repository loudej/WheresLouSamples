using Microsoft.AspNet.Builder;
using Microsoft.AspNet.Http;

public class Startup 
{
    public void Configure(IBuilder app)
    {
        app.Run(async context =>
        {
            context.Response.ContentType = "text/plain";
            await context.Response.WriteAsync("Hello World!");        
        });
    }
}
