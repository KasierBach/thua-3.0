-- =============================================
-- Tạo cơ sở dữ liệu PostgreSQL cho Fashion Store
-- =============================================

-- Tạo các bảng chính
-- =============================================

-- Tạo bảng Categories (Danh mục sản phẩm)
CREATE TABLE IF NOT EXISTS Categories (
    CategoryID SERIAL PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL UNIQUE,
    Description TEXT,
    CreatedAt TIMESTAMP DEFAULT NOW()
);

-- Tạo bảng Products (Sản phẩm)
CREATE TABLE IF NOT EXISTS Products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    Description TEXT,
    Price DECIMAL(18,2) NOT NULL CHECK (Price > 0),
    CategoryID INTEGER NOT NULL,
    ImageURL VARCHAR(500),
    CreatedAt TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);

-- Tạo bảng Colors (Màu sắc)
CREATE TABLE IF NOT EXISTS Colors (
    ColorID SERIAL PRIMARY KEY,
    ColorName VARCHAR(50) NOT NULL UNIQUE
);

-- Tạo bảng Sizes (Kích thước)
CREATE TABLE IF NOT EXISTS Sizes (
    SizeID SERIAL PRIMARY KEY,
    SizeName VARCHAR(50) NOT NULL UNIQUE
);

-- Tạo bảng ProductVariants (Biến thể sản phẩm)
CREATE TABLE IF NOT EXISTS ProductVariants (
    VariantID SERIAL PRIMARY KEY,
    ProductID INTEGER NOT NULL,
    ColorID INTEGER NOT NULL,
    SizeID INTEGER NOT NULL,
    Quantity INTEGER NOT NULL DEFAULT 0 CHECK (Quantity >= 0),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE,
    FOREIGN KEY (ColorID) REFERENCES Colors(ColorID),
    FOREIGN KEY (SizeID) REFERENCES Sizes(SizeID),
    UNIQUE(ProductID, ColorID, SizeID)
);

-- Tạo bảng Customers (Khách hàng)
CREATE TABLE IF NOT EXISTS Customers (
    CustomerID SERIAL PRIMARY KEY,
    FullName VARCHAR(255) NOT NULL,
    Email VARCHAR(255) NOT NULL UNIQUE,
    Password VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(20),
    Address TEXT,
    CreatedAt TIMESTAMP DEFAULT NOW(),
    DarkModeEnabled BOOLEAN DEFAULT FALSE
);

-- Tạo bảng Orders (Đơn hàng)
CREATE TABLE IF NOT EXISTS Orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    OrderDate TIMESTAMP DEFAULT NOW(),
    TotalAmount DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status VARCHAR(50) DEFAULT 'Pending' CHECK (Status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    PaymentMethod VARCHAR(100),
    ShippingAddress TEXT NOT NULL,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

-- Tạo bảng OrderDetails (Chi tiết đơn hàng)
CREATE TABLE IF NOT EXISTS OrderDetails (
    OrderDetailID SERIAL PRIMARY KEY,
    OrderID INTEGER NOT NULL,
    VariantID INTEGER NOT NULL,
    Quantity INTEGER NOT NULL CHECK (Quantity > 0),
    Price DECIMAL(18,2) NOT NULL CHECK (Price > 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (VariantID) REFERENCES ProductVariants(VariantID)
);

-- Tạo bảng Wishlist
CREATE TABLE IF NOT EXISTS Wishlist (
    WishlistID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    ProductID INTEGER NOT NULL,
    AddedDate TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE,
    UNIQUE(CustomerID, ProductID)
);

-- Tạo bảng Reviews
CREATE TABLE IF NOT EXISTS Reviews (
    ReviewID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    ProductID INTEGER NOT NULL,
    Rating INTEGER NOT NULL CHECK (Rating >= 1 AND Rating <= 5),
    Comment TEXT,
    ReviewDate TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE,
    UNIQUE(CustomerID, ProductID)
);

-- Tạo bảng ProductComments
CREATE TABLE IF NOT EXISTS ProductComments (
    CommentID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    ProductID INTEGER NOT NULL,
    Content TEXT NOT NULL,
    CommentDate TIMESTAMP DEFAULT NOW(),
    AdminReply TEXT,
    ReplyDate TIMESTAMP,
    IsVisible BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE
);

-- Tạo bảng ContactMessages
CREATE TABLE IF NOT EXISTS ContactMessages (
    MessageID SERIAL PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    Subject VARCHAR(255),
    Message TEXT NOT NULL,
    SubmitDate TIMESTAMP DEFAULT NOW(),
    Status VARCHAR(50) DEFAULT 'New' CHECK (Status IN ('New', 'Processing', 'Replied'))
);

-- Tạo bảng NewsletterSubscribers
CREATE TABLE IF NOT EXISTS NewsletterSubscribers (
    SubscriberID SERIAL PRIMARY KEY,
    Email VARCHAR(255) NOT NULL UNIQUE,
    SubscribeDate TIMESTAMP DEFAULT NOW(),
    IsActive BOOLEAN DEFAULT TRUE
);

-- Tạo bảng PasswordResetTokens
CREATE TABLE IF NOT EXISTS PasswordResetTokens (
    TokenID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL,
    Token VARCHAR(255) NOT NULL UNIQUE,
    ExpiryDate TIMESTAMP NOT NULL,
    IsUsed BOOLEAN DEFAULT FALSE,
    CreatedAt TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

-- =============================================
-- Tạo các chỉ mục để tối ưu hiệu suất
-- =============================================

CREATE INDEX IF NOT EXISTS idx_products_category ON Products(CategoryID);
CREATE INDEX IF NOT EXISTS idx_products_price ON Products(Price);
CREATE INDEX IF NOT EXISTS idx_products_name ON Products(ProductName);
CREATE INDEX IF NOT EXISTS idx_productvariants_product ON ProductVariants(ProductID);
CREATE INDEX IF NOT EXISTS idx_productvariants_color ON ProductVariants(ColorID);
CREATE INDEX IF NOT EXISTS idx_productvariants_size ON ProductVariants(SizeID);
CREATE INDEX IF NOT EXISTS idx_productvariants_quantity ON ProductVariants(Quantity);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON Orders(CustomerID);
CREATE INDEX IF NOT EXISTS idx_orders_date ON Orders(OrderDate);
CREATE INDEX IF NOT EXISTS idx_orders_status ON Orders(Status);
CREATE INDEX IF NOT EXISTS idx_orderdetails_order ON OrderDetails(OrderID);
CREATE INDEX IF NOT EXISTS idx_orderdetails_variant ON OrderDetails(VariantID);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON Reviews(ProductID);
CREATE INDEX IF NOT EXISTS idx_reviews_customer ON Reviews(CustomerID);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON Reviews(Rating);
CREATE INDEX IF NOT EXISTS idx_wishlist_customer ON Wishlist(CustomerID);
CREATE INDEX IF NOT EXISTS idx_wishlist_product ON Wishlist(ProductID);
CREATE INDEX IF NOT EXISTS idx_productcomments_product ON ProductComments(ProductID);
CREATE INDEX IF NOT EXISTS idx_productcomments_customer ON ProductComments(CustomerID);
CREATE INDEX IF NOT EXISTS idx_productcomments_visible ON ProductComments(IsVisible);
CREATE INDEX IF NOT EXISTS idx_contactmessages_status ON ContactMessages(Status);
CREATE INDEX IF NOT EXISTS idx_contactmessages_date ON ContactMessages(SubmitDate);
CREATE INDEX IF NOT EXISTS idx_newsletter_active ON NewsletterSubscribers(IsActive);
CREATE INDEX IF NOT EXISTS idx_newsletter_email ON NewsletterSubscribers(Email);
CREATE INDEX IF NOT EXISTS idx_passwordreset_token ON PasswordResetTokens(Token);
CREATE INDEX IF NOT EXISTS idx_passwordreset_customer ON PasswordResetTokens(CustomerID);
CREATE INDEX IF NOT EXISTS idx_passwordreset_expiry ON PasswordResetTokens(ExpiryDate);

-- =============================================
-- Thêm dữ liệu mẫu cho Categories
-- =============================================

INSERT INTO Categories (CategoryName, Description) VALUES
('Áo nam', 'Các loại áo dành cho nam giới'),
('Quần nam', 'Các loại quần dành cho nam giới'),
('Áo nữ', 'Các loại áo dành cho nữ giới'),
('Quần nữ', 'Các loại quần dành cho nữ giới'),
('Váy đầm', 'Các loại váy và đầm dành cho nữ giới'),
('Phụ kiện', 'Các loại phụ kiện thời trang')
ON CONFLICT (CategoryName) DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho Colors
-- =============================================

INSERT INTO Colors (ColorName) VALUES
('Đen'),
('Trắng'),
('Đỏ'),
('Xanh dương'),
('Xanh lá'),
('Vàng'),
('Hồng'),
('Xám'),
('Nâu')
ON CONFLICT (ColorName) DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho Sizes
-- =============================================

INSERT INTO Sizes (SizeName) VALUES
('S'),
('M'),
('L'),
('XL'),
('XXL'),
('28'),
('29'),
('30'),
('31'),
('32'),
('33'),
('34')
ON CONFLICT (SizeName) DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho Products
-- =============================================

INSERT INTO Products (ProductName, Description, Price, CategoryID, ImageURL) VALUES
('Áo sơ mi nam trắng', 'Áo sơ mi nam màu trắng chất liệu cotton cao cấp, thiết kế đơn giản, lịch sự', 350000, 1, 'images/ao-so-mi-nam-trang.jpg'),
('Áo thun nam đen', 'Áo thun nam màu đen chất liệu cotton, thiết kế đơn giản, thoải mái', 250000, 1, 'images/ao-thun-nam-den.jpg'),
('Quần jean nam xanh', 'Quần jean nam màu xanh đậm, chất liệu denim co giãn, form slim fit', 450000, 2, 'images/quan-jean-nam-xanh.jpg'),
('Quần kaki nam nâu', 'Quần kaki nam màu nâu, chất liệu kaki cao cấp, form regular', 400000, 2, 'images/quan-kaki-nam-nau.jpg'),
('Áo sơ mi nữ trắng', 'Áo sơ mi nữ màu trắng chất liệu lụa, thiết kế thanh lịch', 320000, 3, 'images/ao-so-mi-nu-trang.jpg'),
('Áo thun nữ hồng', 'Áo thun nữ màu hồng pastel, chất liệu cotton mềm mại', 220000, 3, 'images/ao-thun-nu-hong.jpg'),
('Quần jean nữ xanh nhạt', 'Quần jean nữ màu xanh nhạt, chất liệu denim co giãn, form skinny', 420000, 4, 'images/quan-jean-nu-xanh-nhat.jpg'),
('Váy đầm suông đen', 'Váy đầm suông màu đen, chất liệu vải mềm, thiết kế đơn giản, thanh lịch', 550000, 5, 'images/vay-dam-suong-den.jpg'),
('Váy đầm xòe hoa', 'Váy đầm xòe họa tiết hoa, chất liệu vải mềm mại, phù hợp mùa hè', 650000, 5, 'images/vay-dam.jpg'),
('Thắt lưng da nam', 'Thắt lưng da bò màu đen, khóa kim loại cao cấp', 300000, 6, 'images/phu-kien.jpg'),
('Áo sơ mi nam kẻ sọc', 'Áo sơ mi nam kẻ sọc xanh trắng, chất liệu cotton thoáng mát', 380000, 1, 'images/ao-nam.jpg'),
('Áo polo nam thể thao', 'Áo polo nam thể thao, chất liệu thun co giãn, thoáng khí', 280000, 1, 'images/ao-nam.jpg'),
('Quần short nam kaki', 'Quần short nam kaki, phù hợp mùa hè, form regular', 320000, 2, 'images/quan-nam.jpg'),
('Quần jogger nam', 'Quần jogger nam chất liệu nỉ, co giãn tốt, phù hợp thể thao', 350000, 2, 'images/quan-nam.jpg'),
('Áo kiểu nữ công sở', 'Áo kiểu nữ công sở, thiết kế thanh lịch, chất liệu lụa cao cấp', 420000, 3, 'images/ao-nu.jpg'),
('Áo khoác nữ nhẹ', 'Áo khoác nữ nhẹ chất liệu dù, chống nắng, chống gió nhẹ', 450000, 3, 'images/ao-khoac-nu-nhe.jpg'),
('Quần culottes nữ', 'Quần culottes nữ ống rộng, chất liệu vải mềm, thoáng mát', 380000, 4, 'images/quan-nu.jpg'),
('Quần legging nữ thể thao', 'Quần legging nữ thể thao, co giãn 4 chiều, thoát mồ hôi tốt', 250000, 4, 'images/quan-nu.jpg'),
('Váy liền thân công sở', 'Váy liền thân công sở, thiết kế thanh lịch, kín đáo', 580000, 5, 'images/vay-dam.jpg'),
('Đầm maxi đi biển', 'Đầm maxi đi biển, chất liệu voan nhẹ, họa tiết hoa', 620000, 5, 'images/vay-dam.jpg'),
('Mũ bucket thời trang', 'Mũ bucket thời trang, chất liệu cotton, phù hợp đi chơi, dã ngoại', 180000, 6, 'images/phu-kien.jpg'),
('Túi xách nữ công sở', 'Túi xách nữ công sở, chất liệu da PU cao cấp, nhiều ngăn tiện lợi', 480000, 6, 'images/phu-kien.jpg')
ON CONFLICT DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho Customers
-- =============================================

INSERT INTO Customers (FullName, Email, Password, PhoneNumber, Address) VALUES
('Nguyễn Văn An', 'an.nguyen@example.com', 'scrypt:32768:8:1$salt$hash', '0901234567', '123 Đường Lê Lợi, Quận 1, TP.HCM'),
('Trần Thị Bình', 'binh.tran@example.com', 'scrypt:32768:8:1$salt$hash', '0912345678', '456 Đường Nguyễn Huệ, Quận 1, TP.HCM'),
('Lê Văn Cường', 'cuong.le@example.com', 'scrypt:32768:8:1$salt$hash', '0923456789', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM'),
('Phạm Thị Dung', 'dung.pham@example.com', 'scrypt:32768:8:1$salt$hash', '0934567890', '101 Đường Võ Văn Tần, Quận 3, TP.HCM'),
('Hoàng Văn Em', 'em.hoang@example.com', 'scrypt:32768:8:1$salt$hash', '0945678901', '202 Đường Nguyễn Thị Minh Khai, Quận 1, TP.HCM'),
('Nguyễn Thị Hương', 'huong.nguyen@example.com', 'scrypt:32768:8:1$salt$hash', '0987654321', '25 Đường Lý Tự Trọng, Quận 1, TP.HCM'),
('Trần Văn Minh', 'minh.tran@example.com', 'scrypt:32768:8:1$salt$hash', '0976543210', '42 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM'),
('Lê Thị Lan', 'lan.le@example.com', 'scrypt:32768:8:1$salt$hash', '0965432109', '78 Đường Trần Hưng Đạo, Quận 5, TP.HCM'),
('Phạm Văn Đức', 'duc.pham@example.com', 'scrypt:32768:8:1$salt$hash', '0954321098', '15 Đường Lê Duẩn, Quận 1, TP.HCM'),
('Vũ Thị Mai', 'mai.vu@example.com', 'scrypt:32768:8:1$salt$hash', '0943210987', '63 Đường Nguyễn Trãi, Quận 5, TP.HCM'),
('Đặng Văn Hùng', 'hung.dang@example.com', 'scrypt:32768:8:1$salt$hash', '0932109876', '92 Đường Võ Thị Sáu, Quận 3, TP.HCM'),
('Hoàng Thị Thảo', 'thao.hoang@example.com', 'scrypt:32768:8:1$salt$hash', '0921098765', '37 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM'),
('Ngô Văn Tùng', 'tung.ngo@example.com', 'scrypt:32768:8:1$salt$hash', '0910987654', '54 Đường Phan Đình Phùng, Quận Phú Nhuận, TP.HCM'),
('Bùi Thị Hà', 'ha.bui@example.com', 'scrypt:32768:8:1$salt$hash', '0909876543', '29 Đường Nguyễn Văn Cừ, Quận 5, TP.HCM'),
('Đỗ Văn Nam', 'nam.do@example.com', 'scrypt:32768:8:1$salt$hash', '0898765432', '81 Đường Cách Mạng Tháng 8, Quận 10, TP.HCM'),
('Nguyễn Thị Linh', 'linh.nguyen@example.com', 'scrypt:32768:8:1$salt$hash', '0887654321', '12 Đường Hai Bà Trưng, Quận 1, TP.HCM'),
('Trần Văn Hải', 'hai.tran@example.com', 'scrypt:32768:8:1$salt$hash', '0876543210', '34 Đường Pasteur, Quận 1, TP.HCM'),
('Lê Thị Nga', 'nga.le@example.com', 'scrypt:32768:8:1$salt$hash', '0865432109', '56 Đường Nguyễn Du, Quận 1, TP.HCM'),
('Phạm Văn Tuấn', 'tuan.pham@example.com', 'scrypt:32768:8:1$salt$hash', '0854321098', '78 Đường Lê Thánh Tôn, Quận 1, TP.HCM'),
('Admin User', 'admin@fashionstore.com', 'scrypt:32768:8:1$salt$hash', '0843210987', '90 Đường Đồng Khởi, Quận 1, TP.HCM')
ON CONFLICT (Email) DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho ProductVariants
-- =============================================

-- Áo sơ mi nam trắng (ProductID: 1)
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity) VALUES
(1, 2, 1, 20), -- Trắng, S
(1, 2, 2, 30), -- Trắng, M
(1, 2, 3, 25), -- Trắng, L
(1, 2, 4, 15), -- Trắng, XL
-- Áo thun nam đen (ProductID: 2)
(2, 1, 1, 25), -- Đen, S
(2, 1, 2, 35), -- Đen, M
(2, 1, 3, 30), -- Đen, L
(2, 1, 4, 20), -- Đen, XL
(2, 8, 1, 15), -- Xám, S
(2, 8, 2, 25), -- Xám, M
(2, 8, 3, 20), -- Xám, L
(2, 8, 4, 10), -- Xám, XL
-- Quần jean nam xanh (ProductID: 3)
(3, 4, 6, 15),  -- Xanh dương, 28
(3, 4, 7, 20),  -- Xanh dương, 29
(3, 4, 8, 25),  -- Xanh dương, 30
(3, 4, 9, 20),  -- Xanh dương, 31
(3, 4, 10, 15), -- Xanh dương, 32
(3, 4, 11, 10), -- Xanh dương, 33
-- Quần kaki nam nâu (ProductID: 4)
(4, 9, 6, 10),  -- Nâu, 28
(4, 9, 7, 15),  -- Nâu, 29
(4, 9, 8, 20),  -- Nâu, 30
(4, 9, 9, 15),  -- Nâu, 31
(4, 9, 10, 10), -- Nâu, 32
(4, 9, 11, 5),  -- Nâu, 33
-- Áo sơ mi nữ trắng (ProductID: 5)
(5, 2, 1, 20), -- Trắng, S
(5, 2, 2, 30), -- Trắng, M
(5, 2, 3, 20), -- Trắng, L
-- Áo thun nữ hồng (ProductID: 6)
(6, 7, 1, 25), -- Hồng, S
(6, 7, 2, 35), -- Hồng, M
(6, 7, 3, 25), -- Hồng, L
(6, 2, 1, 20), -- Trắng, S
(6, 2, 2, 30), -- Trắng, M
(6, 2, 3, 20), -- Trắng, L
-- Quần jean nữ xanh nhạt (ProductID: 7)
(7, 4, 6, 15),  -- Xanh dương, 28
(7, 4, 7, 20),  -- Xanh dương, 29
(7, 4, 8, 15),  -- Xanh dương, 30
(7, 4, 9, 10),  -- Xanh dương, 31
-- Váy đầm suông đen (ProductID: 8)
(8, 1, 1, 15), -- Đen, S
(8, 1, 2, 25), -- Đen, M
(8, 1, 3, 15), -- Đen, L
-- Váy đầm xòe hoa (ProductID: 9)
(9, 7, 1, 10), -- Hồng, S
(9, 7, 2, 20), -- Hồng, M
(9, 7, 3, 10), -- Hồng, L
-- Thắt lưng da nam (ProductID: 10)
(10, 1, 1, 30), -- Đen, S
(10, 9, 1, 25), -- Nâu, S
-- Áo sơ mi nam kẻ sọc (ProductID: 11)
(11, 4, 1, 15), -- Xanh dương, S
(11, 4, 2, 25), -- Xanh dương, M
(11, 4, 3, 20), -- Xanh dương, L
(11, 4, 4, 10), -- Xanh dương, XL
-- Áo polo nam thể thao (ProductID: 12)
(12, 1, 1, 20), -- Đen, S
(12, 1, 2, 30), -- Đen, M
(12, 1, 3, 25), -- Đen, L
(12, 4, 1, 15), -- Xanh dương, S
(12, 4, 2, 25), -- Xanh dương, M
(12, 4, 3, 20), -- Xanh dương, L
(12, 3, 1, 10), -- Đỏ, S
(12, 3, 2, 15), -- Đỏ, M
(12, 3, 3, 10), -- Đỏ, L
-- Quần short nam kaki (ProductID: 13)
(13, 1, 8, 20),  -- Đen, 30
(13, 1, 9, 15),  -- Đen, 31
(13, 1, 10, 10), -- Đen, 32
(13, 9, 8, 15),  -- Nâu, 30
(13, 9, 9, 10),  -- Nâu, 31
(13, 9, 10, 5),  -- Nâu, 32
(13, 8, 8, 15),  -- Xám, 30
(13, 8, 9, 10),  -- Xám, 31
(13, 8, 10, 5),  -- Xám, 32
-- Quần jogger nam (ProductID: 14)
(14, 1, 1, 25), -- Đen, S
(14, 1, 2, 35), -- Đen, M
(14, 1, 3, 30), -- Đen, L
(14, 8, 1, 20), -- Xám, S
(14, 8, 2, 30), -- Xám, M
(14, 8, 3, 25), -- Xám, L
-- Áo kiểu nữ công sở (ProductID: 15)
(15, 2, 1, 15), -- Trắng, S
(15, 2, 2, 25), -- Trắng, M
(15, 2, 3, 20), -- Trắng, L
(15, 1, 1, 10), -- Đen, S
(15, 1, 2, 20), -- Đen, M
(15, 1, 3, 15), -- Đen, L
(15, 4, 1, 10), -- Xanh dương, S
(15, 4, 2, 15), -- Xanh dương, M
(15, 4, 3, 10), -- Xanh dương, L
-- Áo khoác nữ nhẹ (ProductID: 16)
(16, 1, 1, 15), -- Đen, S
(16, 1, 2, 25), -- Đen, M
(16, 1, 3, 20), -- Đen, L
(16, 8, 1, 10), -- Xám, S
(16, 8, 2, 20), -- Xám, M
(16, 8, 3, 15), -- Xám, L
(16, 7, 1, 10), -- Hồng, S
(16, 7, 2, 15), -- Hồng, M
(16, 7, 3, 10), -- Hồng, L
-- Quần culottes nữ (ProductID: 17)
(17, 1, 1, 20), -- Đen, S
(17, 1, 2, 30), -- Đen, M
(17, 1, 3, 25), -- Đen, L
(17, 2, 1, 15), -- Trắng, S
(17, 2, 2, 25), -- Trắng, M
(17, 2, 3, 20), -- Trắng, L
(17, 9, 1, 10), -- Nâu, S
(17, 9, 2, 15), -- Nâu, M
(17, 9, 3, 10), -- Nâu, L
-- Quần legging nữ thể thao (ProductID: 18)
(18, 1, 1, 30), -- Đen, S
(18, 1, 2, 40), -- Đen, M
(18, 1, 3, 35), -- Đen, L
(18, 8, 1, 25), -- Xám, S
(18, 8, 2, 35), -- Xám, M
(18, 8, 3, 30), -- Xám, L
(18, 4, 1, 20), -- Xanh dương, S
(18, 4, 2, 30), -- Xanh dương, M
(18, 4, 3, 25), -- Xanh dương, L
-- Váy liền thân công sở (ProductID: 19)
(19, 1, 1, 15), -- Đen, S
(19, 1, 2, 25), -- Đen, M
(19, 1, 3, 20), -- Đen, L
(19, 4, 1, 10), -- Xanh dương, S
(19, 4, 2, 20), -- Xanh dương, M
(19, 4, 3, 15), -- Xanh dương, L
(19, 8, 1, 10), -- Xám, S
(19, 8, 2, 15), -- Xám, M
(19, 8, 3, 10), -- Xám, L
-- Đầm maxi đi biển (ProductID: 20)
(20, 7, 1, 10), -- Hồng, S
(20, 7, 2, 20), -- Hồng, M
(20, 7, 3, 15), -- Hồng, L
(20, 4, 1, 10), -- Xanh dương, S
(20, 4, 2, 15), -- Xanh dương, M
(20, 4, 3, 10), -- Xanh dương, L
(20, 6, 1, 5),  -- Vàng, S
(20, 6, 2, 10), -- Vàng, M
(20, 6, 3, 5),  -- Vàng, L
-- Mũ bucket thời trang (ProductID: 21)
(21, 1, 1, 25), -- Đen, S
(21, 2, 1, 20), -- Trắng, S
(21, 9, 1, 15), -- Nâu, S
(21, 8, 1, 15), -- Xám, S
(21, 4, 1, 10), -- Xanh dương, S
-- Túi xách nữ công sở (ProductID: 22)
(22, 1, 1, 20), -- Đen, S
(22, 9, 1, 15), -- Nâu, S
(22, 8, 1, 10), -- Xám, S
(22, 2, 1, 10)  -- Trắng, S
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- =============================================
-- Thêm dữ liệu mẫu cho Orders
-- =============================================

INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status, PaymentMethod, ShippingAddress) VALUES
(1, '2024-01-15 10:30:00', 700000, 'Delivered', 'COD', '123 Đường Lê Lợi, Quận 1, TP.HCM'),
(2, '2024-01-20 14:15:00', 450000, 'Delivered', 'Bank Transfer', '456 Đường Nguyễn Huệ, Quận 1, TP.HCM'),
(3, '2024-02-05 09:45:00', 850000, 'Shipped', 'Credit Card', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM'),
(4, '2024-02-10 16:20:00', 320000, 'Processing', 'COD', '101 Đường Võ Văn Tần, Quận 3, TP.HCM'),
(5, '2024-02-15 11:00:00', 550000, 'Pending', 'Bank Transfer', '202 Đường Nguyễn Thị Minh Khai, Quận 1, TP.HCM'),
(6, '2024-03-01 13:30:00', 920000, 'Delivered', 'Credit Card', '25 Đường Lý Tự Trọng, Quận 1, TP.HCM'),
(7, '2024-03-05 15:45:00', 380000, 'Delivered', 'COD', '42 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM'),
(8, '2024-03-10 10:15:00', 650000, 'Shipped', 'Bank Transfer', '78 Đường Trần Hưng Đạo, Quận 5, TP.HCM'),
(9, '2024-03-15 14:30:00', 480000, 'Processing', 'COD', '15 Đường Lê Duẩn, Quận 1, TP.HCM'),
(10, '2024-03-20 12:00:00', 750000, 'Pending', 'Credit Card', '63 Đường Nguyễn Trãi, Quận 5, TP.HCM'),
(11, '2024-04-01 09:30:00', 420000, 'Delivered', 'Bank Transfer', '92 Đường Võ Thị Sáu, Quận 3, TP.HCM'),
(12, '2024-04-05 16:45:00', 680000, 'Delivered', 'COD', '37 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM'),
(13, '2024-04-10 11:20:00', 350000, 'Shipped', 'Credit Card', '54 Đường Phan Đình Phùng, Quận Phú Nhuận, TP.HCM'),
(14, '2024-04-15 13:15:00', 580000, 'Processing', 'Bank Transfer', '29 Đường Nguyễn Văn Cừ, Quận 5, TP.HCM'),
(15, '2024-04-20 15:00:00', 720000, 'Pending', 'COD', '81 Đường Cách Mạng Tháng 8, Quận 10, TP.HCM'),
(16, '2024-05-01 10:45:00', 450000, 'Delivered', 'Credit Card', '12 Đường Hai Bà Trưng, Quận 1, TP.HCM'),
(17, '2024-05-05 14:20:00', 620000, 'Delivered', 'Bank Transfer', '34 Đường Pasteur, Quận 1, TP.HCM'),
(18, '2024-05-10 12:30:00', 380000, 'Shipped', 'COD', '56 Đường Nguyễn Du, Quận 1, TP.HCM'),
(19, '2024-05-15 16:10:00', 750000, 'Processing', 'Credit Card', '78 Đường Lê Thánh Tôn, Quận 1, TP.HCM'),
(20, '2024-05-20 11:50:00', 520000, 'Pending', 'Bank Transfer', '90 Đường Đồng Khởi, Quận 1, TP.HCM');

-- =============================================
-- Thêm dữ liệu mẫu cho OrderDetails
-- =============================================

INSERT INTO OrderDetails (OrderID, VariantID, Quantity, Price) VALUES
-- Order 1: CustomerID 1
(1, 1, 2, 350000), -- Áo sơ mi nam trắng, S, 2 cái
(1, 2, 1, 350000), -- Áo sơ mi nam trắng, M, 1 cái
-- Order 2: CustomerID 2
(2, 15, 1, 450000), -- Quần jean nam xanh, 28, 1 cái
-- Order 3: CustomerID 3
(3, 5, 1, 250000), -- Áo thun nam đen, S, 1 cái
(3, 25, 1, 320000), -- Áo sơ mi nữ trắng, S, 1 cái
(3, 33, 1, 280000), -- Áo polo nam thể thao, S, 1 cái
-- Order 4: CustomerID 4
(4, 29, 1, 220000), -- Áo thun nữ hồng, S, 1 cái
(4, 43, 1, 100000), -- Thắt lưng da nam, 1 cái
-- Order 5: CustomerID 5
(5, 37, 1, 550000), -- Váy đầm suông đen, S, 1 cái
-- Order 6: CustomerID 6
(6, 6, 2, 250000), -- Áo thun nam đen, M, 2 cái
(6, 26, 1, 320000), -- Áo sơ mi nữ trắng, M, 1 cái
(6, 16, 1, 450000), -- Quần jean nam xanh, 29, 1 cái
-- Order 7: CustomerID 7
(7, 45, 1, 380000), -- Áo sơ mi nam kẻ sọc, M, 1 cái
-- Order 8: CustomerID 8
(8, 40, 1, 650000), -- Váy đầm xòe hoa, M, 1 cái
-- Order 9: CustomerID 9
(9, 48, 1, 280000), -- Áo polo nam thể thao, M, 1 cái
(9, 54, 1, 200000), -- Quần short nam kaki, 30, 1 cái
-- Order 10: CustomerID 10
(10, 7, 1, 250000), -- Áo thun nam đen, L, 1 cái
(10, 27, 1, 320000), -- Áo sơ mi nữ trắng, L, 1 cái
(10, 21, 1, 180000), -- Quần jean nữ xanh nhạt, 28, 1 cái
-- Thêm các order details khác
(11, 60, 1, 350000), -- Quần jogger nam, S, 1 cái
(11, 29, 1, 70000), -- Áo thun nữ hồng, S, 1 cái
(12, 65, 1, 420000), -- Áo kiểu nữ công sở, M, 1 cái
(12, 71, 1, 260000), -- Áo khoác nữ nhẹ, M, 1 cái
(13, 4, 1, 350000), -- Áo sơ mi nam trắng, XL, 1 cái
(14, 77, 1, 380000), -- Quần culottes nữ, M, 1 cái
(14, 82, 1, 200000), -- Quần legging nữ thể thao, M, 1 cái
(15, 88, 1, 320000), -- Váy liền thân công sở, M, 1 cái
(15, 93, 1, 400000), -- Đầm maxi đi biển, M, 1 cái
(16, 8, 1, 250000), -- Áo thun nam đen, XL, 1 cái
(16, 51, 1, 200000), -- Áo polo nam thể thao, L, 1 cái
(17, 22, 1, 420000), -- Quần jean nữ xanh nhạt, 29, 1 cái
(17, 99, 1, 200000), -- Mũ bucket thời trang, 1 cái
(18, 67, 1, 380000), -- Áo kiểu nữ công sở, L, 1 cái
(19, 94, 1, 620000), -- Đầm maxi đi biển, L, 1 cái
(19, 44, 1, 130000), -- Thắt lưng da nam, 1 cái
(20, 85, 1, 250000), -- Quần legging nữ thể thao, L, 1 cái
(20, 103, 1, 270000); -- Túi xách nữ công sở, 1 cái

-- =============================================
-- Thêm dữ liệu mẫu cho Reviews
-- =============================================

INSERT INTO Reviews (CustomerID, ProductID, Rating, Comment, ReviewDate) VALUES
(1, 1, 5, 'Áo sơ mi chất lượng tốt, vải mềm mại, form đẹp. Rất hài lòng!', '2024-01-20 10:00:00'),
(2, 3, 4, 'Quần jean đẹp, chất liệu tốt nhưng hơi chật ở phần đùi.', '2024-01-25 14:30:00'),
(3, 2, 5, 'Áo thun cotton mềm, thoáng mát, giá cả hợp lý.', '2024-02-10 09:15:00'),
(4, 6, 4, 'Áo thun nữ màu hồng xinh xắn, chất liệu ok.', '2024-02-20 16:45:00'),
(5, 8, 5, 'Váy đầm suông rất đẹp, thiết kế thanh lịch, phù hợp đi làm.', '2024-02-25 11:20:00'),
(6, 1, 4, 'Áo sơ mi nam tốt, nhưng cần cải thiện về đường may.', '2024-03-05 13:00:00'),
(7, 11, 5, 'Áo sơ mi kẻ sọc rất đẹp, chất lượng tuyệt vời!', '2024-03-10 15:30:00'),
(8, 9, 4, 'Váy đầm xòe hoa xinh, nhưng hơi mỏng.', '2024-03-15 10:45:00'),
(9, 12, 5, 'Áo polo thể thao thoáng mát, phù hợp tập gym.', '2024-03-20 14:15:00'),
(10, 2, 3, 'Áo thun bình thường, không có gì đặc biệt.', '2024-03-25 12:30:00'),
(11, 14, 4, 'Quần jogger thoải mái, co giãn tốt.', '2024-04-05 09:00:00'),
(12, 15, 5, 'Áo kiểu công sở rất đẹp, chất liệu lụa mềm mại.', '2024-04-10 16:20:00'),
(13, 1, 5, 'Áo sơ mi nam chất lượng cao, đáng tiền!', '2024-04-15 11:45:00'),
(14, 17, 4, 'Quần culottes thoải mái, phù hợp mùa hè.', '2024-04-20 13:10:00'),
(15, 19, 5, 'Váy liền thân công sở thanh lịch, rất hài lòng.', '2024-04-25 15:50:00'),
(16, 2, 4, 'Áo thun nam chất lượng tốt, giá hợp lý.', '2024-05-05 10:30:00'),
(17, 7, 3, 'Quần jean nữ bình thường, không nổi bật.', '2024-05-10 14:00:00'),
(18, 15, 4, 'Áo kiểu nữ đẹp, nhưng cần cẩn thận khi giặt.', '2024-05-15 12:15:00'),
(19, 20, 5, 'Đầm maxi đi biển rất xinh, chất liệu nhẹ nhàng.', '2024-05-20 16:40:00'),
(20, 18, 4, 'Quần legging thể thao co giãn tốt, thoải mái.', '2024-05-25 11:00:00');

-- =============================================
-- Thêm dữ liệu mẫu cho Wishlist
-- =============================================

INSERT INTO Wishlist (CustomerID, ProductID, AddedDate) VALUES
(1, 5, '2024-01-10 10:00:00'),  -- Áo sơ mi nữ trắng
(1, 9, '2024-01-15 14:30:00'),  -- Váy đầm xòe hoa
(2, 12, '2024-01-20 09:15:00'), -- Áo polo nam thể thao
(3, 16, '2024-02-01 16:45:00'), -- Áo khoác nữ nhẹ
(4, 20, '2024-02-05 11:20:00'), -- Đầm maxi đi biển
(5, 22, '2024-02-10 13:00:00'), -- Túi xách nữ công sở
(6, 4, '2024-02-15 15:30:00'),  -- Quần kaki nam nâu
(7, 18, '2024-02-20 10:45:00'), -- Quần legging nữ thể thao
(8, 11, '2024-02-25 14:15:00'), -- Áo sơ mi nam kẻ sọc
(9, 19, '2024-03-01 12:30:00'), -- Váy liền thân công sở
(10, 21, '2024-03-05 09:00:00'), -- Mũ bucket thời trang
(11, 13, '2024-03-10 16:20:00'), -- Quần short nam kaki
(12, 17, '2024-03-15 11:45:00'), -- Quần culottes nữ
(13, 6, '2024-03-20 13:10:00'),  -- Áo thun nữ hồng
(14, 14, '2024-03-25 15:50:00'), -- Quần jogger nam
(15, 8, '2024-04-01 10:30:00'),  -- Váy đầm suông đen
(16, 15, '2024-04-05 14:00:00'), -- Áo kiểu nữ công sở
(17, 3, '2024-04-10 12:15:00'),  -- Quần jean nam xanh
(18, 10, '2024-04-15 16:40:00'), -- Thắt lưng da nam
(19, 7, '2024-04-20 11:00:00'),  -- Quần jean nữ xanh nhạt
(20, 1, '2024-04-25 13:25:00');  -- Áo sơ mi nam trắng

-- =============================================
-- Thêm dữ liệu mẫu cho ProductComments
-- =============================================

INSERT INTO ProductComments (CustomerID, ProductID, Content, CommentDate, IsVisible) VALUES
(1, 1, 'Áo này có size nào phù hợp với người cao 1m75 không ạ?', '2024-01-15 10:30:00', true),
(2, 1, 'Chất liệu áo có co giãn không? Tôi muốn mua làm quà.', '2024-01-18 14:20:00', true),
(3, 3, 'Quần jean này có bị phai màu sau khi giặt không?', '2024-02-05 09:45:00', true),
(4, 6, 'Áo thun nữ này có màu nào khác ngoài hồng không?', '2024-02-12 16:15:00', true),
(5, 8, 'Váy này phù hợp với người có chiều cao bao nhiêu?', '2024-02-20 11:00:00', true),
(6, 12, 'Áo polo này có chống tia UV không? Tôi hay chơi thể thao ngoài trời.', '2024-03-01 13:30:00', true),
(7, 15, 'Áo kiểu này có cần ủi không? Chất liệu có dễ nhăn không?', '2024-03-08 15:45:00', true),
(8, 20, 'Đầm maxi này có lót trong không? Chất liệu có trong suốt không?', '2024-03-15 10:20:00', true),
(9, 2, 'Áo thun này có bị co rút sau khi giặt không?', '2024-03-22 14:10:00', true),
(10, 7, 'Quần jean nữ này có form nào khác ngoài skinny không?', '2024-03-28 12:50:00', true),
(11, 14, 'Quần jogger này có túi zip không? Tôi cần để điện thoại khi chạy bộ.', '2024-04-03 09:25:00', true),
(12, 19, 'Váy công sở này có cần mặc áo lót đặc biệt không?', '2024-04-10 16:35:00', true),
(13, 21, 'Mũ bucket này có chống nước không? Tôi định đi du lịch.', '2024-04-17 11:15:00', true),
(14, 4, 'Quần kaki này có bị bạc màu sau thời gian dài không?', '2024-04-24 13:40:00', true),
(15, 16, 'Áo khoác này có hood không? Tôi thấy trong hình không rõ.', '2024-05-01 15:20:00', true),
(16, 9, 'Váy đầm xòe này có lót trong không? Chất liệu có mỏng không?', '2024-05-08 10:55:00', true),
(17, 18, 'Quần legging này có độ dày như thế nào? Có thấu không?', '2024-05-15 14:30:00', true),
(18, 11, 'Áo sơ mi kẻ sọc này có dễ ủi không? Tôi không giỏi ủi đồ.', '2024-05-22 12:05:00', true),
(19, 22, 'Túi xách này có ngăn laptop không? Kích thước bao nhiêu?', '2024-05-28 16:50:00', true),
(20, 5, 'Áo sơ mi nữ này có phù hợp đi phỏng vấn không?', '2024-06-02 11:40:00', true);

-- =============================================
-- Thêm dữ liệu mẫu cho ContactMessages
-- =============================================

INSERT INTO ContactMessages (Name, Email, Subject, Message, SubmitDate, Status) VALUES
('Nguyễn Văn Hùng', 'hung.nguyen@email.com', 'Hỏi về chính sách đổi trả', 'Tôi muốn hỏi về chính sách đổi trả hàng. Nếu sản phẩm không vừa size thì có được đổi không?', '2024-01-10 09:30:00', 'Replied'),
('Trần Thị Lan', 'lan.tran@email.com', 'Khiếu nại về chất lượng sản phẩm', 'Tôi đã mua áo sơ mi nhưng sau 1 lần giặt đã bị phai màu. Mong shop hỗ trợ.', '2024-01-15 14:20:00', 'Processing'),
('Lê Văn Minh', 'minh.le@email.com', 'Hỏi về thời gian giao hàng', 'Shop có giao hàng nhanh không? Tôi cần gấp để dự tiệc cuối tuần.', '2024-01-20 10:45:00', 'Replied'),
('Phạm Thị Hoa', 'hoa.pham@email.com', 'Yêu cầu tư vấn size', 'Tôi cao 1m60, nặng 50kg thì nên chọn size nào cho váy đầm?', '2024-01-25 16:15:00', 'New'),
('Hoàng Văn Đức', 'duc.hoang@email.com', 'Hỏi về sản phẩm mới', 'Shop có kế hoạch ra mắt bộ sưu tập mùa hè không?', '2024-02-01 11:30:00', 'New'),
('Vũ Thị Mai', 'mai.vu@email.com', 'Phản hồi tích cực', 'Tôi rất hài lòng với chất lượng sản phẩm và dịch vụ của shop. Cảm ơn!', '2024-02-05 13:50:00', 'Replied'),
('Đặng Văn Nam', 'nam.dang@email.com', 'Hỏi về chương trình khuyến mãi', 'Shop có chương trình giảm giá nào sắp tới không?', '2024-02-10 15:20:00', 'Processing'),
('Ngô Thị Linh', 'linh.ngo@email.com', 'Yêu cầu hỗ trợ đặt hàng', 'Tôi gặp lỗi khi thanh toán online. Mong shop hỗ trợ.', '2024-02-15 09:40:00', 'Replied'),
('Bùi Văn Tùng', 'tung.bui@email.com', 'Hỏi về chất liệu sản phẩm', 'Quần jean có chứa spandex không? Tôi cần loại co giãn.', '2024-02-20 12:10:00', 'New'),
('Đỗ Thị Nga', 'nga.do@email.com', 'Góp ý cải thiện website', 'Website của shop nên có thêm tính năng so sánh sản phẩm.', '2024-02-25 14:35:00', 'Processing'),
('Trịnh Văn Hải', 'hai.trinh@email.com', 'Hỏi về giao hàng tỉnh', 'Shop có giao hàng ra Đà Nẵng không? Phí ship bao nhiêu?', '2024-03-01 10:25:00', 'Replied'),
('Lý Thị Thảo', 'thao.ly@email.com', 'Yêu cầu catalog', 'Shop có catalog in không? Tôi muốn xem trực tiếp.', '2024-03-05 16:45:00', 'New'),
('Phan Văn Quang', 'quang.phan@email.com', 'Hỏi về bảo hành', 'Sản phẩm có được bảo hành không? Thời gian bao lâu?', '2024-03-10 11:55:00', 'Processing'),
('Võ Thị Kim', 'kim.vo@email.com', 'Phản ánh về nhân viên', 'Nhân viên tư vấn rất nhiệt tình và chuyên nghiệp. Cảm ơn!', '2024-03-15 13:20:00', 'Replied'),
('Đinh Văn Long', 'long.dinh@email.com', 'Hỏi về thanh toán', 'Shop có nhận thanh toán qua ví điện tử không?', '2024-03-20 15:40:00', 'New'),
('Huỳnh Thị Xuân', 'xuan.huynh@email.com', 'Yêu cầu tư vấn phối đồ', 'Tôi mua áo sơ mi trắng, nên phối với quần gì cho đẹp?', '2024-03-25 09:15:00', 'Processing'),
('Cao Văn Bình', 'binh.cao@email.com', 'Hỏi về membership', 'Shop có chương trình thành viên VIP không?', '2024-03-30 12:30:00', 'New'),
('Tôn Thị Hương', 'huong.ton@email.com', 'Góp ý về packaging', 'Shop nên cải thiện cách đóng gói để bảo vệ sản phẩm tốt hơn.', '2024-04-05 14:50:00', 'Replied'),
('Lâm Văn Thành', 'thanh.lam@email.com', 'Hỏi về size chart', 'Bảng size của shop có chính xác không? Tôi lo chọn sai size.', '2024-04-10 10:05:00', 'Processing'),
('Dương Thị Phương', 'phuong.duong@email.com', 'Yêu cầu hỗ trợ sau bán hàng', 'Tôi cần hướng dẫn cách bảo quản áo len. Cảm ơn shop!', '2024-04-15 16:25:00', 'New');

-- =============================================
-- Thêm dữ liệu mẫu cho NewsletterSubscribers
-- =============================================

INSERT INTO NewsletterSubscribers (Email, SubscribeDate, IsActive) VALUES
('subscriber1@email.com', '2024-01-05 10:00:00', true),
('subscriber2@email.com', '2024-01-10 14:30:00', true),
('subscriber3@email.com', '2024-01-15 09:15:00', true),
('subscriber4@email.com', '2024-01-20 16:45:00', false),
('subscriber5@email.com', '2024-01-25 11:20:00', true),
('subscriber6@email.com', '2024-02-01 13:00:00', true),
('subscriber7@email.com', '2024-02-05 15:30:00', true),
('subscriber8@email.com', '2024-02-10 10:45:00', false),
('subscriber9@email.com', '2024-02-15 14:15:00', true),
('subscriber10@email.com', '2024-02-20 12:30:00', true),
('newsletter.fan1@gmail.com', '2024-02-25 09:00:00', true),
('fashion.lover@yahoo.com', '2024-03-01 16:20:00', true),
('style.enthusiast@hotmail.com', '2024-03-05 11:45:00', true),
('trendy.shopper@outlook.com', '2024-03-10 13:10:00', false),
('chic.customer@gmail.com', '2024-03-15 15:50:00', true),
('elegant.buyer@email.com', '2024-03-20 10:30:00', true),
('modern.fashionista@yahoo.com', '2024-03-25 14:00:00', true),
('stylish.subscriber@gmail.com', '2024-04-01 12:15:00', true),
('fashion.updates@hotmail.com', '2024-04-05 16:40:00', false),
('trend.alerts@outlook.com', '2024-04-10 11:00:00', true),
('style.news@email.com', '2024-04-15 13:25:00', true),
('fashion.deals@gmail.com', '2024-04-20 15:45:00', true),
('clothing.updates@yahoo.com', '2024-04-25 09:30:00', true),
('wardrobe.tips@hotmail.com', '2024-05-01 12:50:00', false),
('outfit.ideas@outlook.com', '2024-05-05 14:20:00', true),
('fashion.inspiration@gmail.com', '2024-05-10 10:40:00', true),
('style.guide@email.com', '2024-05-15 16:10:00', true),
('trendy.updates@yahoo.com', '2024-05-20 11:35:00', true),
('chic.newsletter@hotmail.com', '2024-05-25 13:55:00', false),
('elegant.fashion@outlook.com', '2024-05-30 15:15:00', true)
ON CONFLICT (Email) DO NOTHING;

-- =============================================
-- Tạo trigger để tự động cập nhật TotalAmount trong Orders
-- =============================================

CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Orders 
    SET TotalAmount = (
        SELECT COALESCE(SUM(Quantity * Price), 0)
        FROM OrderDetails 
        WHERE OrderID = COALESCE(NEW.OrderID, OLD.OrderID)
    )
    WHERE OrderID = COALESCE(NEW.OrderID, OLD.OrderID);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Tạo trigger cho INSERT, UPDATE, DELETE trên OrderDetails
DROP TRIGGER IF EXISTS trigger_update_order_total_insert ON OrderDetails;
DROP TRIGGER IF EXISTS trigger_update_order_total_update ON OrderDetails;
DROP TRIGGER IF EXISTS trigger_update_order_total_delete ON OrderDetails;

CREATE TRIGGER trigger_update_order_total_insert
    AFTER INSERT ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

CREATE TRIGGER trigger_update_order_total_update
    AFTER UPDATE ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

CREATE TRIGGER trigger_update_order_total_delete
    AFTER DELETE ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

-- =============================================
-- Tạo view để thống kê doanh thu
-- =============================================

CREATE OR REPLACE VIEW RevenueStats AS
SELECT 
    DATE_TRUNC('month', OrderDate) as Month,
    COUNT(*) as TotalOrders,
    SUM(TotalAmount) as TotalRevenue,
    AVG(TotalAmount) as AverageOrderValue
FROM Orders 
WHERE Status IN ('Delivered', 'Shipped')
GROUP BY DATE_TRUNC('month', OrderDate)
ORDER BY Month DESC;

-- =============================================
-- Tạo view để thống kê sản phẩm bán chạy
-- =============================================

CREATE OR REPLACE VIEW TopSellingProducts AS
SELECT 
    p.ProductID,
    p.ProductName,
    p.Price,
    c.CategoryName,
    SUM(od.Quantity) as TotalSold,
    SUM(od.Quantity * od.Price) as TotalRevenue
FROM Products p
JOIN Categories c ON p.CategoryID = c.CategoryID
JOIN ProductVariants pv ON p.ProductID = pv.ProductID
JOIN OrderDetails od ON pv.VariantID = od.VariantID
JOIN Orders o ON od.OrderID = o.OrderID
WHERE o.Status IN ('Delivered', 'Shipped')
GROUP BY p.ProductID, p.ProductName, p.Price, c.CategoryName
ORDER BY TotalSold DESC;

-- =============================================
-- Tạo view để thống kê khách hàng
-- =============================================

CREATE OR REPLACE VIEW CustomerStats AS
SELECT 
    c.CustomerID,
    c.FullName,
    c.Email,
    COUNT(o.OrderID) as TotalOrders,
    SUM(o.TotalAmount) as TotalSpent,
    AVG(o.TotalAmount) as AverageOrderValue,
    MAX(o.OrderDate) as LastOrderDate
FROM Customers c
LEFT JOIN Orders o ON c.CustomerID = o.CustomerID
GROUP BY c.CustomerID, c.FullName, c.Email
ORDER BY TotalSpent DESC NULLS LAST;

-- =============================================
-- Cập nhật lại TotalAmount cho các orders hiện có
-- =============================================

UPDATE Orders 
SET TotalAmount = (
    SELECT COALESCE(SUM(od.Quantity * od.Price), 0)
    FROM OrderDetails od
    WHERE od.OrderID = Orders.OrderID
);

-- =============================================
-- Thông báo hoàn thành
-- =============================================

DO $$
BEGIN
    RAISE NOTICE 'Database setup completed successfully!';
    RAISE NOTICE 'Total Categories: %', (SELECT COUNT(*) FROM Categories);
    RAISE NOTICE 'Total Products: %', (SELECT COUNT(*) FROM Products);
    RAISE NOTICE 'Total Product Variants: %', (SELECT COUNT(*) FROM ProductVariants);
    RAISE NOTICE 'Total Customers: %', (SELECT COUNT(*) FROM Customers);
    RAISE NOTICE 'Total Orders: %', (SELECT COUNT(*) FROM Orders);
    RAISE NOTICE 'Total Order Details: %', (SELECT COUNT(*) FROM OrderDetails);
    RAISE NOTICE 'Total Reviews: %', (SELECT COUNT(*) FROM Reviews);
    RAISE NOTICE 'Total Wishlist Items: %', (SELECT COUNT(*) FROM Wishlist);
    RAISE NOTICE 'Total Comments: %', (SELECT COUNT(*) FROM ProductComments);
    RAISE NOTICE 'Total Contact Messages: %', (SELECT COUNT(*) FROM ContactMessages);
    RAISE NOTICE 'Total Newsletter Subscribers: %', (SELECT COUNT(*) FROM NewsletterSubscribers);
END $$;