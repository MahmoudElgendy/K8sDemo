namespace Shopping.Client.Models
{
    public class Product
    {
        // Id, Name,Category, Description, Price, and ImageUrl properties
        public Guid Id { get; set; }
        public string Name { get; set; }
        public string Category { get; set; }
        public string Description { get; set; }
        public string ImageFile { get; set; }
        public decimal Price { get; set; }

    }
}
