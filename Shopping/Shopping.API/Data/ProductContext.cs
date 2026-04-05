namespace Shopping.API.Data
{
    public static class ProductContext
    {
        public static readonly List<Models.Product> Products = new()
        {
            new Models.Product
            {
                Id = Guid.NewGuid(),
                Name = "Laptop",
                Category = "Electronics",
                Description = "A high-performance laptop for work and play.",
                Price = 999.99m,
                ImageFile = "laptop.jpg"
            },
            new Models.Product
            {
                Id = Guid.NewGuid(),
                Name = "Smartphone",
                Category = "Electronics",
                Description = "A sleek smartphone with the latest features.",
                Price = 699.99m,
                ImageFile = "smartphone.jpg"
            },
            new Models.Product
            {
                Id = Guid.NewGuid(),
                Name = "Headphones",
                Category = "Audio",
                Description = "Noise-cancelling headphones for immersive sound.",
                Price = 199.99m,
                ImageFile = "headphones.jpg"
            },
            new Models.Product
            {
                Id = Guid.NewGuid(),
                Name = "Coffee Maker",
                Category = "Home Appliances",
                Description = "Brew the perfect cup of coffee every morning.",
                Price = 49.99m,
                ImageFile = "coffeemaker.jpg"
            }
        };
    }
}
