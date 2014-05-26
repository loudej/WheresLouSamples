using Microsoft.AspNet.Builder;

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
