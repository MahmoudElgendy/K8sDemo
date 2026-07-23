using Microsoft.EntityFrameworkCore;
using Shopping.API.Data;

namespace Shopping.API
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.

            builder.Services.AddControllers();
            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen();
            builder.Services.AddDbContext<ProductContext>(options =>
                options.UseSqlServer(
                        builder.Configuration.GetConnectionString("DefaultConnection")));

            var app = builder.Build();
            // try
            // {
            //     using var scope = app.Services.CreateScope();

            //     var dbContext = scope.ServiceProvider.GetRequiredService<ProductContext>();

            //     dbContext.Database.Migrate();

            //     Console.WriteLine("Database migration completed successfully.");
            // }
            // catch (Exception ex)
            // {
            //     Console.WriteLine("Database migration failed:");
            //     Console.WriteLine(ex);

            //     throw;
            // }

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseAuthorization();


            app.MapControllers();

            app.Run();
        }
    }
}
