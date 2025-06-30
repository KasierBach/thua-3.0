-- =============================================
-- Tạo cơ sở dữ liệu PostgreSQL
-- =============================================
-- CREATE DATABASE fashionstoredb;
-- \c fashionstoredb;

-- =============================================
-- Tạo các bảng
-- =============================================

-- Tạo bảng Customers (Khách hàng)
CREATE TABLE IF NOT EXISTS Customers (
    CustomerID SERIAL PRIMARY KEY,
    FullName VARCHAR(255) NOT NULL,
    Email VARCHAR(255) NOT NULL UNIQUE,
    Password VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(20) UNIQUE,
    Address TEXT,
    CreatedAt TIMESTAMP DEFAULT NOW(),
    DarkModeEnabled BOOLEAN DEFAULT FALSE
);

-- Tạo bảng Categories (Danh mục sản phẩm)
CREATE TABLE IF NOT EXISTS Categories (
    CategoryID SERIAL PRIMARY KEY,
    CategoryName VARCHAR(100) NOT NULL UNIQUE,
    Description VARCHAR(255)
);

-- Tạo bảng Products (Sản phẩm)
CREATE TABLE IF NOT EXISTS Products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(255) NOT NULL,
    Description TEXT,
    Price DECIMAL(18,2) NOT NULL,
    CategoryID INTEGER REFERENCES Categories(CategoryID),
    ImageURL VARCHAR(255),
    CreatedAt TIMESTAMP DEFAULT NOW()
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
    ProductID INTEGER REFERENCES Products(ProductID),
    ColorID INTEGER REFERENCES Colors(ColorID),
    SizeID INTEGER REFERENCES Sizes(SizeID),
    Quantity INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT UC_ProductVariant UNIQUE (ProductID, ColorID, SizeID)
);

-- Tạo bảng Orders (Đơn hàng)
CREATE TABLE IF NOT EXISTS Orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID INTEGER REFERENCES Customers(CustomerID),
    OrderDate TIMESTAMP DEFAULT NOW(),
    TotalAmount DECIMAL(18,2) NOT NULL,
    Status VARCHAR(50) DEFAULT 'Pending',
    PaymentMethod VARCHAR(100),
    ShippingAddress TEXT
);

-- Tạo bảng OrderDetails (Chi tiết đơn hàng)
CREATE TABLE IF NOT EXISTS OrderDetails (
    OrderDetailID SERIAL PRIMARY KEY,
    OrderID INTEGER REFERENCES Orders(OrderID),
    VariantID INTEGER REFERENCES ProductVariants(VariantID),
    Quantity INTEGER NOT NULL,
    Price DECIMAL(18,2) NOT NULL
);

-- Tạo bảng Wishlist
CREATE TABLE IF NOT EXISTS Wishlist (
    WishlistID SERIAL PRIMARY KEY,
    CustomerID INTEGER REFERENCES Customers(CustomerID),
    ProductID INTEGER REFERENCES Products(ProductID),
    AddedDate TIMESTAMP DEFAULT NOW(),
    CONSTRAINT UC_CustomerProduct UNIQUE (CustomerID, ProductID)
);

-- Tạo bảng Reviews
CREATE TABLE IF NOT EXISTS Reviews (
    ReviewID SERIAL PRIMARY KEY,
    CustomerID INTEGER REFERENCES Customers(CustomerID),
    ProductID INTEGER REFERENCES Products(ProductID),
    Rating INTEGER NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comment TEXT,
    ReviewDate TIMESTAMP DEFAULT NOW(),
    CONSTRAINT UC_CustomerProductReview UNIQUE (CustomerID, ProductID)
);

-- Tạo bảng ContactMessages
CREATE TABLE IF NOT EXISTS ContactMessages (
    MessageID SERIAL PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    Subject VARCHAR(255),
    Message TEXT NOT NULL,
    SubmitDate TIMESTAMP DEFAULT NOW(),
    Status VARCHAR(50) DEFAULT 'New'
);

-- Tạo bảng NewsletterSubscribers
CREATE TABLE IF NOT EXISTS NewsletterSubscribers (
    SubscriberID SERIAL PRIMARY KEY,
    Email VARCHAR(255) NOT NULL UNIQUE,
    SubscribeDate TIMESTAMP DEFAULT NOW(),
    IsActive BOOLEAN DEFAULT TRUE
);

-- Tạo bảng ProductComments
CREATE TABLE IF NOT EXISTS ProductComments (
    CommentID SERIAL PRIMARY KEY,
    CustomerID INTEGER REFERENCES Customers(CustomerID),
    ProductID INTEGER REFERENCES Products(ProductID),
    Content TEXT NOT NULL,
    CommentDate TIMESTAMP DEFAULT NOW(),
    AdminReply TEXT,
    ReplyDate TIMESTAMP,
    IsVisible BOOLEAN DEFAULT TRUE
);

-- Tạo bảng PasswordResetTokens
CREATE TABLE IF NOT EXISTS PasswordResetTokens (
    TokenID SERIAL PRIMARY KEY,
    CustomerID INTEGER NOT NULL REFERENCES Customers(CustomerID),
    Token VARCHAR(100) NOT NULL,
    ExpiryDate TIMESTAMP NOT NULL,
    IsUsed BOOLEAN DEFAULT FALSE,
    CreatedAt TIMESTAMP DEFAULT NOW()
);

-- =============================================
-- Tạo các View
-- =============================================

-- View 1: Thống kê doanh thu theo tháng
CREATE OR REPLACE VIEW vw_MonthlyRevenue AS
SELECT 
    EXTRACT(YEAR FROM OrderDate) AS Year,
    EXTRACT(MONTH FROM OrderDate) AS Month,
    SUM(TotalAmount) AS TotalRevenue,
    COUNT(OrderID) AS OrderCount
FROM 
    Orders
WHERE 
    Status != 'Cancelled'
GROUP BY 
    EXTRACT(YEAR FROM OrderDate), EXTRACT(MONTH FROM OrderDate);

-- View 2: Thống kê doanh thu theo danh mục sản phẩm
CREATE OR REPLACE VIEW vw_CategoryRevenue AS
SELECT 
    c.CategoryID,
    c.CategoryName,
    SUM(od.Quantity * od.Price) AS TotalRevenue,
    SUM(od.Quantity) AS TotalQuantitySold
FROM 
    Categories c
    JOIN Products p ON c.CategoryID = p.CategoryID
    JOIN ProductVariants pv ON p.ProductID = pv.ProductID
    JOIN OrderDetails od ON pv.VariantID = od.VariantID
    JOIN Orders o ON od.OrderID = o.OrderID
WHERE 
    o.Status != 'Cancelled'
GROUP BY 
    c.CategoryID, c.CategoryName;

-- View 3: Sản phẩm còn hàng
CREATE OR REPLACE VIEW vw_AvailableProducts AS
SELECT 
    p.ProductID,
    p.ProductName,
    c.CategoryName,
    s.SizeName,
    cl.ColorName,
    pv.Quantity AS AvailableStock,
    p.Price
FROM 
    Products p
    JOIN Categories c ON p.CategoryID = c.CategoryID
    JOIN ProductVariants pv ON p.ProductID = pv.ProductID
    JOIN Sizes s ON pv.SizeID = s.SizeID
    JOIN Colors cl ON pv.ColorID = cl.ColorID
WHERE 
    pv.Quantity > 0;

-- View 4: Sản phẩm bán chạy
CREATE OR REPLACE VIEW vw_BestSellingProducts AS
SELECT 
    p.ProductID,
    p.ProductName,
    SUM(od.Quantity) AS TotalSold,
    p.Price,
    c.CategoryName
FROM OrderDetails od
JOIN ProductVariants pv ON od.VariantID = pv.VariantID
JOIN Products p ON pv.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY p.ProductID, p.ProductName, p.Price, c.CategoryName
ORDER BY SUM(od.Quantity) DESC
LIMIT 4;

-- View 5: Lịch sử mua hàng của khách hàng
CREATE OR REPLACE VIEW vw_CustomerPurchaseHistory AS
SELECT 
    c.CustomerID,
    c.FullName,
    c.Email,
    o.OrderID,
    o.OrderDate,
    o.TotalAmount,
    o.Status,
    p.ProductName,
    cl.ColorName,
    s.SizeName,
    od.Quantity,
    od.Price,
    (od.Quantity * od.Price) AS Subtotal
FROM 
    Customers c
    JOIN Orders o ON c.CustomerID = o.CustomerID
    JOIN OrderDetails od ON o.OrderID = od.OrderID
    JOIN ProductVariants pv ON od.VariantID = pv.VariantID
    JOIN Products p ON pv.ProductID = p.ProductID
    JOIN Colors cl ON pv.ColorID = cl.ColorID
    JOIN Sizes s ON pv.SizeID = s.SizeID;

-- View 6: Product ratings
CREATE OR REPLACE VIEW vw_ProductRatings AS
SELECT 
    p.ProductID,
    p.ProductName,
    COUNT(r.ReviewID) AS ReviewCount,
    AVG(r.Rating::float) AS AverageRating
FROM 
    Products p
    LEFT JOIN Reviews r ON p.ProductID = r.ProductID
GROUP BY 
    p.ProductID, p.ProductName;

-- =============================================
-- Tạo các Function (thay thế Stored Procedure)
-- =============================================

-- Function 1: Thêm khách hàng mới
CREATE OR REPLACE FUNCTION sp_AddCustomer(
    p_FullName VARCHAR(255),
    p_Email VARCHAR(255),
    p_Password VARCHAR(255),
    p_PhoneNumber VARCHAR(20) DEFAULT NULL,
    p_Address TEXT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_CustomerID INTEGER;
BEGIN
    -- Kiểm tra email đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM Customers WHERE Email = p_Email) THEN
        RAISE EXCEPTION 'Email đã tồn tại trong hệ thống';
    END IF;
    
    -- Kiểm tra số điện thoại đã tồn tại chưa (nếu có)
    IF p_PhoneNumber IS NOT NULL AND EXISTS (SELECT 1 FROM Customers WHERE PhoneNumber = p_PhoneNumber) THEN
        RAISE EXCEPTION 'Số điện thoại đã tồn tại trong hệ thống';
    END IF;
    
    -- Thêm khách hàng mới
    INSERT INTO Customers (FullName, Email, Password, PhoneNumber, Address, CreatedAt)
    VALUES (p_FullName, p_Email, p_Password, p_PhoneNumber, p_Address, NOW())
    RETURNING CustomerID INTO v_CustomerID;
    
    RETURN v_CustomerID;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Tạo đơn hàng mới
CREATE OR REPLACE FUNCTION sp_CreateOrder(
    p_CustomerID INTEGER,
    p_PaymentMethod VARCHAR(100),
    p_ShippingAddress TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_OrderID INTEGER;
BEGIN
    -- Kiểm tra khách hàng tồn tại
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = p_CustomerID) THEN
        RAISE EXCEPTION 'Khách hàng không tồn tại';
    END IF;
    
    -- Tạo đơn hàng mới với tổng tiền ban đầu là 0
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status, PaymentMethod, ShippingAddress)
    VALUES (p_CustomerID, NOW(), 0, 'Pending', p_PaymentMethod, p_ShippingAddress)
    RETURNING OrderID INTO v_OrderID;
    
    RETURN v_OrderID;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Thêm chi tiết đơn hàng
CREATE OR REPLACE FUNCTION sp_AddOrderDetail(
    p_OrderID INTEGER,
    p_VariantID INTEGER,
    p_Quantity INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_AvailableQuantity INTEGER;
    v_CurrentPrice DECIMAL(18,2);
BEGIN
    -- Kiểm tra đơn hàng tồn tại
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = p_OrderID) THEN
        RAISE EXCEPTION 'Đơn hàng không tồn tại';
    END IF;
    
    -- Kiểm tra biến thể sản phẩm tồn tại
    IF NOT EXISTS (SELECT 1 FROM ProductVariants WHERE VariantID = p_VariantID) THEN
        RAISE EXCEPTION 'Biến thể sản phẩm không tồn tại';
    END IF;
    
    -- Kiểm tra số lượng tồn kho
    SELECT Quantity INTO v_AvailableQuantity FROM ProductVariants WHERE VariantID = p_VariantID;
    
    IF v_AvailableQuantity < p_Quantity THEN
        RAISE EXCEPTION 'Số lượng sản phẩm không đủ. Hiện chỉ còn % sản phẩm.', v_AvailableQuantity;
    END IF;
    
    -- Lấy giá sản phẩm hiện tại
    SELECT p.Price INTO v_CurrentPrice
    FROM Products p
    JOIN ProductVariants pv ON p.ProductID = pv.ProductID
    WHERE pv.VariantID = p_VariantID;
    
    -- Thêm chi tiết đơn hàng
    INSERT INTO OrderDetails (OrderID, VariantID, Quantity, Price)
    VALUES (p_OrderID, p_VariantID, p_Quantity, v_CurrentPrice);
    
    -- Cập nhật số lượng tồn kho
    UPDATE ProductVariants 
    SET Quantity = Quantity - p_Quantity
    WHERE VariantID = p_VariantID;
    
    -- Cập nhật tổng tiền đơn hàng
    UPDATE Orders
    SET TotalAmount = (
        SELECT SUM(Quantity * Price)
        FROM OrderDetails
        WHERE OrderID = p_OrderID
    )
    WHERE OrderID = p_OrderID;
    
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- Function 4: Cập nhật trạng thái đơn hàng
CREATE OR REPLACE FUNCTION sp_UpdateOrderStatus(
    p_OrderID INTEGER,
    p_NewStatus VARCHAR(50)
) RETURNS INTEGER AS $$
DECLARE
    v_CurrentStatus VARCHAR(50);
BEGIN
    -- Kiểm tra đơn hàng tồn tại
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = p_OrderID) THEN
        RAISE EXCEPTION 'Đơn hàng không tồn tại';
    END IF;
    
    -- Kiểm tra trạng thái hợp lệ
    IF p_NewStatus NOT IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Trạng thái đơn hàng không hợp lệ';
    END IF;
    
    -- Lấy trạng thái hiện tại
    SELECT Status INTO v_CurrentStatus FROM Orders WHERE OrderID = p_OrderID;
    
    -- Nếu đơn hàng đã bị hủy, không cho phép thay đổi trạng thái
    IF v_CurrentStatus = 'Cancelled' AND p_NewStatus != 'Cancelled' THEN
        RAISE EXCEPTION 'Không thể thay đổi trạng thái của đơn hàng đã bị hủy';
    END IF;
    
    -- Nếu đơn hàng đã giao, không cho phép thay đổi trạng thái (trừ khi hủy)
    IF v_CurrentStatus = 'Delivered' AND p_NewStatus != 'Delivered' AND p_NewStatus != 'Cancelled' THEN
        RAISE EXCEPTION 'Không thể thay đổi trạng thái của đơn hàng đã giao';
    END IF;
    
    -- Nếu đổi từ trạng thái khác sang Cancelled, cần hoàn trả tồn kho
    IF p_NewStatus = 'Cancelled' AND v_CurrentStatus != 'Cancelled' THEN
        -- Hoàn trả tồn kho
        UPDATE ProductVariants pv
        SET Quantity = pv.Quantity + od.Quantity
        FROM OrderDetails od
        WHERE pv.VariantID = od.VariantID AND od.OrderID = p_OrderID;
    END IF;
    
    -- Nếu đổi từ Cancelled sang trạng thái khác, cần trừ lại tồn kho
    IF v_CurrentStatus = 'Cancelled' AND p_NewStatus != 'Cancelled' THEN
        -- Kiểm tra xem có đủ tồn kho không
        IF EXISTS (
            SELECT 1
            FROM OrderDetails od
            JOIN ProductVariants pv ON od.VariantID = pv.VariantID
            WHERE od.OrderID = p_OrderID AND pv.Quantity < od.Quantity
        ) THEN
            RAISE EXCEPTION 'Không đủ tồn kho để khôi phục đơn hàng';
        END IF;
        
        -- Trừ lại tồn kho
        UPDATE ProductVariants pv
        SET Quantity = pv.Quantity - od.Quantity
        FROM OrderDetails od
        WHERE pv.VariantID = od.VariantID AND od.OrderID = p_OrderID;
    END IF;
    
    -- Cập nhật trạng thái đơn hàng
    UPDATE Orders
    SET Status = p_NewStatus
    WHERE OrderID = p_OrderID;
    
    RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- Function 5: Tìm kiếm sản phẩm
CREATE OR REPLACE FUNCTION sp_SearchProducts(
    p_SearchTerm VARCHAR(255) DEFAULT NULL,
    p_CategoryID INTEGER DEFAULT NULL,
    p_MinPrice DECIMAL(18,2) DEFAULT NULL,
    p_MaxPrice DECIMAL(18,2) DEFAULT NULL,
    p_ColorID INTEGER DEFAULT NULL,
    p_SizeID INTEGER DEFAULT NULL,
    p_InStockOnly INTEGER DEFAULT 0
) RETURNS TABLE(
    ProductID INTEGER,
    ProductName VARCHAR(255),
    Description TEXT,
    Price DECIMAL(18,2),
    CategoryID INTEGER,
    CategoryName VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        p.ProductID,
        p.ProductName,
        p.Description,
        p.Price,
        c.CategoryID,
        c.CategoryName
    FROM 
        Products p
        JOIN Categories c ON p.CategoryID = c.CategoryID
        LEFT JOIN ProductVariants pv ON p.ProductID = pv.ProductID
    WHERE
        (p_SearchTerm IS NULL OR p.ProductName ILIKE '%' || p_SearchTerm || '%' OR p.Description ILIKE '%' || p_SearchTerm || '%')
        AND (p_CategoryID IS NULL OR p.CategoryID = p_CategoryID)
        AND (p_MinPrice IS NULL OR p.Price >= p_MinPrice)
        AND (p_MaxPrice IS NULL OR p.Price <= p_MaxPrice)
        AND (p_ColorID IS NULL OR EXISTS (
            SELECT 1 FROM ProductVariants 
            WHERE ProductID = p.ProductID AND ColorID = p_ColorID
        ))
        AND (p_SizeID IS NULL OR EXISTS (
            SELECT 1 FROM ProductVariants 
            WHERE ProductID = p.ProductID AND SizeID = p_SizeID
        ))
        AND (p_InStockOnly = 0 OR EXISTS (
            SELECT 1 FROM ProductVariants 
            WHERE ProductID = p.ProductID AND Quantity > 0
        ))
    ORDER BY
        p.ProductName;
END;
$$ LANGUAGE plpgsql;

-- Function 6: Lấy danh sách đơn hàng của khách hàng
CREATE OR REPLACE FUNCTION sp_GetCustomerOrders(p_CustomerID INTEGER)
RETURNS TABLE(
    OrderID INTEGER,
    OrderDate TIMESTAMP,
    TotalAmount DECIMAL(18,2),
    Status VARCHAR(50),
    PaymentMethod VARCHAR(100),
    ShippingAddress TEXT,
    TotalItems BIGINT
) AS $$
BEGIN
    -- Kiểm tra khách hàng tồn tại
    IF NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID = p_CustomerID) THEN
        RAISE EXCEPTION 'Khách hàng không tồn tại';
    END IF;
    
    RETURN QUERY
    SELECT 
        o.OrderID,
        o.OrderDate,
        o.TotalAmount,
        o.Status,
        o.PaymentMethod,
        o.ShippingAddress,
        COUNT(od.OrderDetailID) AS TotalItems
    FROM 
        Orders o
        LEFT JOIN OrderDetails od ON o.OrderID = od.OrderID
    WHERE 
        o.CustomerID = p_CustomerID
    GROUP BY 
        o.OrderID, o.OrderDate, o.TotalAmount, o.Status, o.PaymentMethod, o.ShippingAddress
    ORDER BY 
        o.OrderDate DESC;
END;
$$ LANGUAGE plpgsql;

-- Function 7: Lấy chi tiết đơn hàng
CREATE OR REPLACE FUNCTION sp_GetOrderDetails(p_OrderID INTEGER)
RETURNS TABLE(
    OrderID INTEGER,
    OrderDate TIMESTAMP,
    TotalAmount DECIMAL(18,2),
    Status VARCHAR(50),
    PaymentMethod VARCHAR(100),
    ShippingAddress TEXT,
    CustomerID INTEGER,
    CustomerName VARCHAR(255),
    CustomerEmail VARCHAR(255),
    CustomerPhone VARCHAR(20)
) AS $$
BEGIN
    -- Kiểm tra đơn hàng tồn tại
    IF NOT EXISTS (SELECT 1 FROM Orders WHERE OrderID = p_OrderID) THEN
        RAISE EXCEPTION 'Đơn hàng không tồn tại';
    END IF;
    
    RETURN QUERY
    SELECT 
        o.OrderID,
        o.OrderDate,
        o.TotalAmount,
        o.Status,
        o.PaymentMethod,
        o.ShippingAddress,
        c.CustomerID,
        c.FullName AS CustomerName,
        c.Email AS CustomerEmail,
        c.PhoneNumber AS CustomerPhone
    FROM 
        Orders o
        JOIN Customers c ON o.CustomerID = c.CustomerID
    WHERE 
        o.OrderID = p_OrderID;
END;
$$ LANGUAGE plpgsql;

-- Function 8: Thêm sản phẩm mới
CREATE OR REPLACE FUNCTION sp_AddProduct(
    p_ProductName VARCHAR(255),
    p_Description TEXT,
    p_Price DECIMAL(18,2),
    p_CategoryID INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_ProductID INTEGER;
BEGIN
    -- Kiểm tra danh mục tồn tại
    IF NOT EXISTS (SELECT 1 FROM Categories WHERE CategoryID = p_CategoryID) THEN
        RAISE EXCEPTION 'Danh mục không tồn tại';
    END IF;
    
    -- Thêm sản phẩm mới
    INSERT INTO Products (ProductName, Description, Price, CategoryID, CreatedAt)
    VALUES (p_ProductName, p_Description, p_Price, p_CategoryID, NOW())
    RETURNING ProductID INTO v_ProductID;
    
    RETURN v_ProductID;
END;
$$ LANGUAGE plpgsql;

-- Function 9: Thêm biến thể sản phẩm
CREATE OR REPLACE FUNCTION sp_AddProductVariant(
    p_ProductID INTEGER,
    p_ColorID INTEGER,
    p_SizeID INTEGER,
    p_Quantity INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_VariantID INTEGER;
BEGIN
    -- Kiểm tra sản phẩm tồn tại
    IF NOT EXISTS (SELECT 1 FROM Products WHERE ProductID = p_ProductID) THEN
        RAISE EXCEPTION 'Sản phẩm không tồn tại';
    END IF;
    
    -- Kiểm tra màu sắc tồn tại
    IF NOT EXISTS (SELECT 1 FROM Colors WHERE ColorID = p_ColorID) THEN
        RAISE EXCEPTION 'Màu sắc không tồn tại';
    END IF;
    
    -- Kiểm tra kích thước tồn tại
    IF NOT EXISTS (SELECT 1 FROM Sizes WHERE SizeID = p_SizeID) THEN
        RAISE EXCEPTION 'Kích thước không tồn tại';
    END IF;
    
    -- Kiểm tra biến thể đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM ProductVariants WHERE ProductID = p_ProductID AND ColorID = p_ColorID AND SizeID = p_SizeID) THEN
        -- Cập nhật số lượng nếu biến thể đã tồn tại
        UPDATE ProductVariants
        SET Quantity = Quantity + p_Quantity
        WHERE ProductID = p_ProductID AND ColorID = p_ColorID AND SizeID = p_SizeID
        RETURNING VariantID INTO v_VariantID;
    ELSE
        -- Thêm biến thể mới
        INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
        VALUES (p_ProductID, p_ColorID, p_SizeID, p_Quantity)
        RETURNING VariantID INTO v_VariantID;
    END IF;
    
    RETURN v_VariantID;
END;
$$ LANGUAGE plpgsql;

-- Function 10: Thống kê doanh thu theo khoảng thời gian
CREATE OR REPLACE FUNCTION sp_GetRevenueByDateRange(
    p_StartDate DATE,
    p_EndDate DATE
) RETURNS TABLE(
    OrderDate DATE,
    OrderCount BIGINT,
    DailyRevenue DECIMAL(18,2)
) AS $$
BEGIN
    -- Kiểm tra ngày hợp lệ
    IF p_StartDate > p_EndDate THEN
        RAISE EXCEPTION 'Ngày bắt đầu không thể sau ngày kết thúc';
    END IF;
    
    -- Thống kê doanh thu theo ngày
    RETURN QUERY
    SELECT 
        o.OrderDate::DATE AS OrderDate,
        COUNT(o.OrderID) AS OrderCount,
        SUM(o.TotalAmount) AS DailyRevenue
    FROM 
        Orders o
    WHERE 
        o.OrderDate::DATE BETWEEN p_StartDate AND p_EndDate
        AND o.Status != 'Cancelled'
    GROUP BY 
        o.OrderDate::DATE
    ORDER BY 
        o.OrderDate::DATE;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Thêm dữ liệu mẫu
-- =============================================

-- Thêm dữ liệu mẫu cho bảng Categories
INSERT INTO Categories (CategoryName, Description)
VALUES 
    ('Áo nam', 'Các loại áo dành cho nam giới'),
    ('Quần nam', 'Các loại quần dành cho nam giới'),
    ('Áo nữ', 'Các loại áo dành cho nữ giới'),
    ('Quần nữ', 'Các loại quần dành cho nữ giới'),
    ('Váy đầm', 'Các loại váy và đầm dành cho nữ giới'),
    ('Phụ kiện', 'Các loại phụ kiện thời trang')
ON CONFLICT (CategoryName) DO NOTHING;

-- Thêm dữ liệu mẫu cho bảng Colors
INSERT INTO Colors (ColorName)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng Sizes
INSERT INTO Sizes (SizeName)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng Customers
INSERT INTO Customers (FullName, Email, Password, PhoneNumber, Address)
VALUES 
    ('Nguyễn Văn An', 'an.nguyen@example.com', 'hashed_password_1', '0901234567', '123 Đường Lê Lợi, Quận 1, TP.HCM'),
    ('Trần Thị Bình', 'binh.tran@example.com', 'hashed_password_2', '0912345678', '456 Đường Nguyễn Huệ, Quận 1, TP.HCM'),
    ('Lê Văn Cường', 'cuong.le@example.com', 'hashed_password_3', '0923456789', '789 Đường Cách Mạng Tháng 8, Quận 3, TP.HCM'),
    ('Phạm Thị Dung', 'dung.pham@example.com', 'hashed_password_4', '0934567890', '101 Đường Võ Văn Tần, Quận 3, TP.HCM'),
    ('Hoàng Văn Em', 'em.hoang@example.com', 'hashed_password_5', '0945678901', '202 Đường Nguyễn Thị Minh Khai, Quận 1, TP.HCM'),
    ('Nguyễn Thị Hương', 'huong.nguyen@example.com', 'password123', '0987654321', '25 Đường Lý Tự Trọng, Quận 1, TP.HCM'),
    ('Trần Văn Minh', 'minh.tran@example.com', 'password456', '0976543210', '42 Đường Nguyễn Đình Chiểu, Quận 3, TP.HCM'),
    ('Lê Thị Lan', 'lan.le@example.com', 'password789', '0965432109', '78 Đường Trần Hưng Đạo, Quận 5, TP.HCM'),
    ('Phạm Văn Đức', 'duc.pham@example.com', 'passwordabc', '0954321098', '15 Đường Lê Duẩn, Quận 1, TP.HCM'),
    ('Vũ Thị Mai', 'mai.vu@example.com', 'passworddef', '0943210987', '63 Đường Nguyễn Trãi, Quận 5, TP.HCM'),
    ('Đặng Văn Hùng', 'hung.dang@example.com', 'passwordghi', '0932109876', '92 Đường Võ Thị Sáu, Quận 3, TP.HCM'),
    ('Hoàng Thị Thảo', 'thao.hoang@example.com', 'passwordjkl', '0921098765', '37 Đường Điện Biên Phủ, Quận Bình Thạnh, TP.HCM'),
    ('Ngô Văn Tùng', 'tung.ngo@example.com', 'passwordmno', '0910987654', '54 Đường Phan Đình Phùng, Quận Phú Nhuận, TP.HCM'),
    ('Bùi Thị Hà', 'ha.bui@example.com', 'passwordpqr', '0909876543', '29 Đường Nguyễn Văn Cừ, Quận 5, TP.HCM'),
    ('Đỗ Văn Nam', 'nam.do@example.com', 'passwordstu', '0898765432', '81 Đường Cách Mạng Tháng 8, Quận 10, TP.HCM'),
    ('Nguyễn Thị Linh', 'linh.nguyen@example.com', 'password111', '0887654321', '12 Đường Hai Bà Trưng, Quận 1, TP.HCM'),
    ('Trần Văn Hải', 'hai.tran@example.com', 'password222', '0876543210', '34 Đường Pasteur, Quận 1, TP.HCM'),
    ('Lê Thị Nga', 'nga.le@example.com', 'password333', '0865432109', '56 Đường Nguyễn Du, Quận 1, TP.HCM'),
    ('Phạm Văn Tuấn', 'tuan.pham@example.com', 'password444', '0854321098', '78 Đường Lê Thánh Tôn, Quận 1, TP.HCM'),
    ('Vũ Thị Hoa', 'hoa.vu@example.com', 'password555', '0843210987', '90 Đường Đồng Khởi, Quận 1, TP.HCM')
ON CONFLICT (Email) DO NOTHING;

-- Thêm dữ liệu mẫu cho bảng Products
INSERT INTO Products (ProductName, Description, Price, CategoryID, ImageURL)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng ProductVariants
-- Áo sơ mi nam trắng
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (1, 2, 1, 20), -- Trắng, S
    (1, 2, 2, 30), -- Trắng, M
    (1, 2, 3, 25), -- Trắng, L
    (1, 2, 4, 15) -- Trắng, XL
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Áo thun nam đen
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (2, 1, 1, 25), -- Đen, S
    (2, 1, 2, 35), -- Đen, M
    (2, 1, 3, 30), -- Đen, L
    (2, 1, 4, 20), -- Đen, XL
    (2, 8, 1, 15), -- Xám, S
    (2, 8, 2, 25), -- Xám, M
    (2, 8, 3, 20), -- Xám, L
    (2, 8, 4, 10) -- Xám, XL
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Quần jean nam xanh
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (3, 4, 6, 15),  -- Xanh dương, 28
    (3, 4, 7, 20),  -- Xanh dương, 29
    (3, 4, 8, 25),  -- Xanh dương, 30
    (3, 4, 9, 20),  -- Xanh dương, 31
    (3, 4, 10, 15), -- Xanh dương, 32
    (3, 4, 11, 10) -- Xanh dương, 33
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Quần kaki nam nâu
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (4, 9, 6, 10),  -- Nâu, 28
    (4, 9, 7, 15),  -- Nâu, 29
    (4, 9, 8, 20),  -- Nâu, 30
    (4, 9, 9, 15),  -- Nâu, 31
    (4, 9, 10, 10), -- Nâu, 32
    (4, 9, 11, 5)  -- Nâu, 33
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Áo sơ mi nữ trắng
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (5, 2, 1, 20), -- Trắng, S
    (5, 2, 2, 30), -- Trắng, M
    (5, 2, 3, 20) -- Trắng, L
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Áo thun nữ hồng
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (6, 7, 1, 25), -- Hồng, S
    (6, 7, 2, 35), -- Hồng, M
    (6, 7, 3, 25), -- Hồng, L
    (6, 2, 1, 20), -- Trắng, S
    (6, 2, 2, 30), -- Trắng, M
    (6, 2, 3, 20) -- Trắng, L
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Quần jean nữ xanh nhạt
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (7, 4, 6, 15),  -- Xanh dương, 28
    (7, 4, 7, 20),  -- Xanh dương, 29
    (7, 4, 8, 15),  -- Xanh dương, 30
    (7, 4, 9, 10)  -- Xanh dương, 31
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Váy đầm suông đen
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (8, 1, 1, 15), -- Đen, S
    (8, 1, 2, 25), -- Đen, M
    (8, 1, 3, 15) -- Đen, L
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Váy đầm xòe hoa (giả sử màu chính là hồng)
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (9, 7, 1, 10), -- Hồng, S
    (9, 7, 2, 20), -- Hồng, M
    (9, 7, 3, 10) -- Hồng, L
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Thắt lưng da nam (chỉ có màu đen và nâu, không có size)
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
    (10, 1, 1, 30), -- Đen, S (giả sử S là size nhỏ)
    (10, 9, 1, 25) -- Nâu, S
ON CONFLICT (ProductID, ColorID, SizeID) DO NOTHING;

-- Thêm các biến thể cho sản phẩm còn lại
INSERT INTO ProductVariants (ProductID, ColorID, SizeID, Quantity)
VALUES 
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
    (14, 8, 2, 30), -- Xám,
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

-- Thêm dữ liệu mẫu cho bảng Orders
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount, Status, PaymentMethod, ShippingAddress)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng OrderDetails
INSERT INTO OrderDetails (OrderID, VariantID, Quantity, Price)
VALUES 
    -- Order 1: CustomerID 1
    (1, 1, 2, 350000), -- Áo sơ mi nam trắng, S, 2 cái
    (1, 5, 1, 350000), -- Áo sơ mi nam trắng, M, 1 cái
    
    -- Order 2: CustomerID 2
    (2, 9, 1, 450000), -- Quần jean nam xanh, 28, 1 cái
    
    -- Order 3: CustomerID 3
    (3, 2, 1, 250000), -- Áo thun nam đen, S, 1 cái
    (3, 15, 1, 320000), -- Áo sơ mi nữ trắng, S, 1 cái
    (3, 19, 1, 280000), -- Áo polo nam thể thao, S, 1 cái
    
    -- Order 4: CustomerID 4
    (4, 18, 1, 220000), -- Áo thun nữ hồng, S, 1 cái
    (4, 22, 1, 100000), -- Thắt lưng da nam, 1 cái (giả sử giá 100k)
    
    -- Order 5: CustomerID 5
    (5, 23, 1, 550000), -- Váy đầm suông đen, S, 1 cái
    
    -- Order 6: CustomerID 6
    (6, 3, 2, 250000), -- Áo thun nam đen, M, 2 cái
    (6, 16, 1, 320000), -- Áo sơ mi nữ trắng, M, 1 cái
    (6, 10, 1, 450000), -- Quần jean nam xanh, 29, 1 cái
    
    -- Order 7: CustomerID 7
    (7, 28, 1, 380000), -- Áo sơ mi nam kẻ sọc, M, 1 cái
    
    -- Order 8: CustomerID 8
    (8, 25, 1, 650000), -- Váy đầm xòe hoa, M, 1 cái
    
    -- Order 9: CustomerID 9
    (9, 30, 1, 280000), -- Áo polo nam thể thao, M, 1 cái
    (10, 35, 1, 320000), -- Quần short nam kaki, 30, 1 cái (giả sử giá 200k)
    
    -- Order 10: CustomerID 10
    (10, 4, 1, 250000), -- Áo thun nam đen, L, 1 cái
    (10, 17, 1, 320000), -- Áo sơ mi nữ trắng, L, 1 cái
    (10, 20, 1, 420000), -- Quần jean nữ xanh nhạt, 28, 1 cái (giả sử giá 180k)
    
    -- Thêm các order details khác
    (11, 40, 1, 350000), -- Quần jogger nam, S, 1 cái
    (11, 19, 1, 220000), -- Áo thun nữ hồng, S, 1 cái (giả sử giá 70k)
    
    (12, 42, 1, 420000), -- Áo kiểu nữ công sở, M, 1 cái
    (12, 46, 1, 450000), -- Áo khoác nữ nhẹ, M, 1 cái (giả sử giá 260k)
    
    (13, 6, 1, 350000), -- Áo sơ mi nam trắng, XL, 1 cái
    
    (14, 49, 1, 380000), -- Quần culottes nữ, M, 1 cái
    (14, 52, 1, 250000), -- Quần legging nữ thể thao, M, 1 cái (giả sử giá 200k)
    
    (15, 56, 1, 580000), -- Váy liền thân công sở, M, 1 cái (giả sử giá 320k)
    (15, 59, 1, 620000), -- Đầm maxi đi biển, M, 1 cái (giả sử giá 400k)
    
    (16, 7, 1, 250000), -- Áo thun nam đen, XL, 1 cái
    (16, 32, 1, 280000), -- Áo polo nam thể thao, L, 1 cái (giả sử giá 200k)
    
    (17, 21, 1, 420000), -- Quần jean nữ xanh nhạt, 29, 1 cái
    (17, 65, 1, 180000), -- Mũ bucket thời trang, 1 cái (giả sử giá 200k)
    
    (18, 43, 1, 420000), -- Áo kiểu nữ công sở, L, 1 cái (giả sử giá 380k)
    
    (19, 60, 1, 620000), -- Đầm maxi đi biển, L, 1 cái
    (19, 26, 1, 280000), -- Thắt lưng da nam, 1 cái (giả sử giá 130k)
    
    (20, 53, 1, 250000), -- Quần legging nữ thể thao, L, 1 cái
    (20, 69, 1, 480000); -- Túi xách nữ công sở, 1 cái (giả sử giá 270k)

-- Thêm dữ liệu mẫu cho bảng Reviews
INSERT INTO Reviews (CustomerID, ProductID, Rating, Comment, ReviewDate)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng Wishlist
INSERT INTO Wishlist (CustomerID, ProductID, AddedDate)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng ProductComments
INSERT INTO ProductComments (CustomerID, ProductID, Content, CommentDate, IsVisible)
VALUES 
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

-- Thêm dữ liệu mẫu cho bảng ContactMessages
INSERT INTO ContactMessages (Name, Email, Subject, Message, SubmitDate, Status)
VALUES 
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
    ('Cao Thị Hương', 'huong.cao@email.com', 'Yêu cầu tư vấn phối đồ', 'Tôi nên phối áo sơ mi trắng với quần gì cho phù hợp?', '2024-03-25 09:15:00', 'Processing'),
    ('Lương Văn Thành', 'thanh.luong@email.com', 'Hỏi về membership', 'Shop có chương trình thành viên VIP không?', '2024-03-30 12:30:00', 'Replied'),
    ('Tạ Thị Loan', 'loan.ta@email.com', 'Góp ý về packaging', 'Shop nên cải thiện cách đóng gói để bảo vệ sản phẩm tốt hơn.', '2024-04-05 14:50:00', 'New'),
    ('Dương Văn Phúc', 'phuc.duong@email.com', 'Hỏi về size chart', 'Bảng size của shop có chính xác không? Tôi lo chọn sai.', '2024-04-10 10:20:00', 'Processing'),
    ('Hồ Thị Yến', 'yen.ho@email.com', 'Cảm ơn dịch vụ', 'Dịch vụ chăm sóc khách hàng của shop rất tốt. Tôi sẽ giới thiệu bạn bè.', '2024-04-15 16:10:00', 'Replied');

-- Thêm dữ liệu mẫu cho bảng NewsletterSubscribers
INSERT INTO NewsletterSubscribers (Email, SubscribeDate, IsActive)
VALUES 
    ('newsletter1@example.com', '2024-01-05 10:00:00', true),
    ('newsletter2@example.com', '2024-01-10 14:30:00', true),
    ('newsletter3@example.com', '2024-01-15 09:15:00', true),
    ('newsletter4@example.com', '2024-01-20 16:45:00', false),
    ('newsletter5@example.com', '2024-01-25 11:20:00', true),
    ('newsletter6@example.com', '2024-02-01 13:00:00', true),
    ('newsletter7@example.com', '2024-02-05 15:30:00', true),
    ('newsletter8@example.com', '2024-02-10 10:45:00', true),
    ('newsletter9@example.com', '2024-02-15 14:15:00', false),
    ('newsletter10@example.com', '2024-02-20 12:30:00', true),
    ('fashion.lover@email.com', '2024-02-25 09:00:00', true),
    ('style.hunter@email.com', '2024-03-01 16:20:00', true),
    ('trendy.shopper@email.com', '2024-03-05 11:45:00', true),
    ('chic.buyer@email.com', '2024-03-10 13:10:00', true),
    ('elegant.customer@email.com', '2024-03-15 15:50:00', false),
    ('modern.fashionista@email.com', '2024-03-20 10:30:00', true),
    ('classic.style@email.com', '2024-03-25 14:00:00', true),
    ('casual.wear@email.com', '2024-04-01 12:15:00', true),
    ('formal.attire@email.com', '2024-04-05 16:40:00', true),
    ('street.fashion@email.com', '2024-04-10 11:00:00', true),
    ('boutique.fan@email.com', '2024-04-15 13:25:00', false),
    ('wardrobe.essentials@email.com', '2024-04-20 15:45:00', true),
    ('seasonal.trends@email.com', '2024-04-25 09:30:00', true),
    ('designer.inspired@email.com', '2024-05-01 12:50:00', true),
    ('affordable.fashion@email.com', '2024-05-05 14:20:00', true);

-- =============================================
-- Tạo các Trigger
-- =============================================

-- Trigger 1: Tự động cập nhật tổng tiền đơn hàng khi thêm/sửa/xóa chi tiết đơn hàng
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Cập nhật tổng tiền cho đơn hàng
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
DROP TRIGGER IF EXISTS tr_update_order_total_insert ON OrderDetails;
CREATE TRIGGER tr_update_order_total_insert
    AFTER INSERT ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

DROP TRIGGER IF EXISTS tr_update_order_total_update ON OrderDetails;
CREATE TRIGGER tr_update_order_total_update
    AFTER UPDATE ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

DROP TRIGGER IF EXISTS tr_update_order_total_delete ON OrderDetails;
CREATE TRIGGER tr_update_order_total_delete
    AFTER DELETE ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

-- Trigger 2: Kiểm tra số lượng tồn kho trước khi thêm chi tiết đơn hàng
CREATE OR REPLACE FUNCTION check_stock_before_order()
RETURNS TRIGGER AS $$
DECLARE
    v_available_quantity INTEGER;
    v_product_name VARCHAR(255);
BEGIN
    -- Lấy số lượng tồn kho hiện tại
    SELECT pv.Quantity, p.ProductName
    INTO v_available_quantity, v_product_name
    FROM ProductVariants pv
    JOIN Products p ON pv.ProductID = p.ProductID
    WHERE pv.VariantID = NEW.VariantID;
    
    -- Kiểm tra số lượng
    IF v_available_quantity < NEW.Quantity THEN
        RAISE EXCEPTION 'Không đủ hàng trong kho cho sản phẩm %. Chỉ còn % sản phẩm.', 
            v_product_name, v_available_quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_check_stock_before_order ON OrderDetails;
CREATE TRIGGER tr_check_stock_before_order
    BEFORE INSERT ON OrderDetails
    FOR EACH ROW
    EXECUTE FUNCTION check_stock_before_order();

-- Trigger 3: Tự động cập nhật tồn kho khi trạng thái đơn hàng thay đổi
CREATE OR REPLACE FUNCTION update_stock_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Nếu đơn hàng chuyển từ trạng thái khác sang 'Cancelled'
    IF OLD.Status != 'Cancelled' AND NEW.Status = 'Cancelled' THEN
        -- Hoàn trả tồn kho
        UPDATE ProductVariants pv
        SET Quantity = pv.Quantity + od.Quantity
        FROM OrderDetails od
        WHERE pv.VariantID = od.VariantID AND od.OrderID = NEW.OrderID;
    END IF;
    
    -- Nếu đơn hàng chuyển từ 'Cancelled' sang trạng thái khác
    IF OLD.Status = 'Cancelled' AND NEW.Status != 'Cancelled' THEN
        -- Trừ lại tồn kho
        UPDATE ProductVariants pv
        SET Quantity = pv.Quantity - od.Quantity
        FROM OrderDetails od
        WHERE pv.VariantID = od.VariantID AND od.OrderID = NEW.OrderID;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_update_stock_on_status_change ON Orders;
CREATE TRIGGER tr_update_stock_on_status_change
    AFTER UPDATE ON Orders
    FOR EACH ROW
    WHEN (OLD.Status IS DISTINCT FROM NEW.Status)
    EXECUTE FUNCTION update_stock_on_status_change();

-- Trigger 4: Tự động xóa token đặt lại mật khẩu đã hết hạn
CREATE OR REPLACE FUNCTION cleanup_expired_tokens()
RETURNS TRIGGER AS $$
BEGIN
    -- Xóa các token đã hết hạn
    DELETE FROM PasswordResetTokens
    WHERE ExpiryDate < NOW() AND IsUsed = false;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tạo trigger chạy mỗi khi có token mới được tạo
DROP TRIGGER IF EXISTS tr_cleanup_expired_tokens ON PasswordResetTokens;
CREATE TRIGGER tr_cleanup_expired_tokens
    AFTER INSERT ON PasswordResetTokens
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_expired_tokens();

-- =============================================
-- Tạo Index để tối ưu hiệu suất
-- =============================================

-- Index cho bảng Products
CREATE INDEX IF NOT EXISTS idx_products_category ON Products(CategoryID);
CREATE INDEX IF NOT EXISTS idx_products_price ON Products(Price);
CREATE INDEX IF NOT EXISTS idx_products_name ON Products(ProductName);

-- Index cho bảng ProductVariants
CREATE INDEX IF NOT EXISTS idx_productvariants_product ON ProductVariants(ProductID);
CREATE INDEX IF NOT EXISTS idx_productvariants_color ON ProductVariants(ColorID);
CREATE INDEX IF NOT EXISTS idx_productvariants_size ON ProductVariants(SizeID);
CREATE INDEX IF NOT EXISTS idx_productvariants_quantity ON ProductVariants(Quantity);

-- Index cho bảng Orders
CREATE INDEX IF NOT EXISTS idx_orders_customer ON Orders(CustomerID);
CREATE INDEX IF NOT EXISTS idx_orders_date ON Orders(OrderDate);
CREATE INDEX IF NOT EXISTS idx_orders_status ON Orders(Status);

-- Index cho bảng OrderDetails
CREATE INDEX IF NOT EXISTS idx_orderdetails_order ON OrderDetails(OrderID);
CREATE INDEX IF NOT EXISTS idx_orderdetails_variant ON OrderDetails(VariantID);

-- Index cho bảng Reviews
CREATE INDEX IF NOT EXISTS idx_reviews_product ON Reviews(ProductID);
CREATE INDEX IF NOT EXISTS idx_reviews_customer ON Reviews(CustomerID);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON Reviews(Rating);

-- Index cho bảng Wishlist
CREATE INDEX IF NOT EXISTS idx_wishlist_customer ON Wishlist(CustomerID);
CREATE INDEX IF NOT EXISTS idx_wishlist_product ON Wishlist(ProductID);

-- Index cho bảng ProductComments
CREATE INDEX IF NOT EXISTS idx_productcomments_product ON ProductComments(ProductID);
CREATE INDEX IF NOT EXISTS idx_productcomments_customer ON ProductComments(CustomerID);
CREATE INDEX IF NOT EXISTS idx_productcomments_visible ON ProductComments(IsVisible);

-- Index cho bảng ContactMessages
CREATE INDEX IF NOT EXISTS idx_contactmessages_status ON ContactMessages(Status);
CREATE INDEX IF NOT EXISTS idx_contactmessages_date ON ContactMessages(SubmitDate);

-- Index cho bảng NewsletterSubscribers
CREATE INDEX IF NOT EXISTS idx_newsletter_active ON NewsletterSubscribers(IsActive);
CREATE INDEX IF NOT EXISTS idx_newsletter_email ON NewsletterSubscribers(Email);

-- Index cho bảng PasswordResetTokens
CREATE INDEX IF NOT EXISTS idx_passwordreset_token ON PasswordResetTokens(Token);
CREATE INDEX IF NOT EXISTS idx_passwordreset_customer ON PasswordResetTokens(CustomerID);
CREATE INDEX IF NOT EXISTS idx_passwordreset_expiry ON PasswordResetTokens(ExpiryDate);

-- =============================================
-- Kết thúc script
-- =============================================

-- Hiển thị thông báo hoàn thành
DO $$
BEGIN
    RAISE NOTICE 'Cơ sở dữ liệu Fashion Store đã được tạo thành công!';
    RAISE NOTICE 'Bao gồm:';
    RAISE NOTICE '- % bảng dữ liệu', (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE');
    RAISE NOTICE '- % view', (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public');
    RAISE NOTICE '- % function', (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION');
    RAISE NOTICE '- % trigger', (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'public');
    RAISE NOTICE 'Dữ liệu mẫu đã được thêm vào các bảng.';
END $$;
