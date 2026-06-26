using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Shopping.API.Migrations
{
    /// <inheritdoc />
    public partial class InitialDb : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Products",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Category = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    ImageFile = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Price = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Products", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "Products",
                columns: new[] { "Id", "Category", "Description", "ImageFile", "Name", "Price" },
                values: new object[,]
                {
                    { 1, "Smart Phone", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-1.png", "IPhone X", 950.00m },
                    { 2, "Smart Phone", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-2.png", "Samsung 10", 840.00m },
                    { 3, "White Appliances", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-3.png", "Huawei Plus", 650.00m },
                    { 4, "White Appliances", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-4.png", "Xiaomi Mi 9", 470.00m },
                    { 5, "Smart Phone", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-5.png", "HTC U11+ Plus", 380.00m },
                    { 6, "Home Kitchen", "This phone is the company's biggest change to its flagship smartphone in years. It includes a borderless.", "product-6.png", "LG G7 ThinQ EndofCourse", 240.00m }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Products");
        }
    }
}
