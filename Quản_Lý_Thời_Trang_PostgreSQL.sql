-- Tạo cơ sở dữ liệu và bảng
CREATE DATABASE IF NOT EXISTS fashionstoredb;

-- Tạo các bảng
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    category_id INTEGER REFERENCES categories(id),
    image_url VARCHAR(500),
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS colors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    hex_code VARCHAR(7)
);

CREATE TABLE IF NOT EXISTS sizes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(10) NOT NULL UNIQUE,
    sort_order INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS product_variants (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    color_id INTEGER REFERENCES colors(id),
    size_id INTEGER REFERENCES sizes(id),
    stock_quantity INTEGER DEFAULT 0,
    sku VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200),
    phone VARCHAR(20),
    address TEXT,
    is_admin BOOLEAN DEFAULT FALSE,
    dark_mode BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    shipping_address TEXT,
    phone VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    variant_id INTEGER REFERENCES product_variants(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wishlist (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

CREATE TABLE IF NOT EXISTS product_comments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    comment TEXT NOT NULL,
    is_approved BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contact_messages (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL,
    subject VARCHAR(200),
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS newsletter_subscribers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(120) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS recently_viewed (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    product_id INTEGER REFERENCES products(id),
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, product_id)
);

-- Chèn dữ liệu mẫu
INSERT INTO categories (name, description) VALUES
('Áo Nam', 'Các loại áo dành cho nam giới'),
('Áo Nữ', 'Các loại áo dành cho nữ giới'),
('Quần Nam', 'Các loại quần dành cho nam giới'),
('Quần Nữ', 'Các loại quần dành cho nữ giới'),
('Váy Đầm', 'Các loại váy đầm dành cho nữ giới'),
('Phụ Kiện', 'Các phụ kiện thời trang');

INSERT INTO colors (name, hex_code) VALUES
('Đen', '#000000'),
('Trắng', '#FFFFFF'),
('Xanh Navy', '#000080'),
('Xanh Nhạt', '#87CEEB'),
('Hồng', '#FFC0CB'),
('Nâu', '#A52A2A'),
('Xám', '#808080'),
('Đỏ', '#FF0000'),
('Vàng', '#FFFF00');

INSERT INTO sizes (name, sort_order) VALUES
('XS', 1),
('S', 2),
('M', 3),
('L', 4),
('XL', 5),
('XXL', 6),
('28', 7),
('29', 8),
('30', 9),
('31', 10),
('32', 11),
('34', 12);

INSERT INTO products (name, description, price, category_id, image_url, is_featured) VALUES
('Áo Thun Nam Đen', 'Áo thun nam màu đen, chất liệu cotton thoáng mát', 299000, 1, '/static/images/ao-thun-nam-den.jpg', TRUE),
('Áo Sơ Mi Nam Trắng', 'Áo sơ mi nam màu trắng, phù hợp đi làm', 599000, 1, '/static/images/ao-so-mi-nam-trang.jpg', TRUE),
('Áo Thun Nữ Hồng', 'Áo thun nữ màu hồng, thiết kế trẻ trung', 259000, 2, '/static/images/ao-thun-nu-hong.jpg', FALSE),
('Áo Sơ Mi Nữ Trắng', 'Áo sơ mi nữ màu trắng, thanh lịch', 549000, 2, '/static/images/ao-so-mi-nu-trang.jpg', TRUE),
('Áo Khoác Nữ Nhẹ', 'Áo khoác nữ nhẹ, phù hợp mùa thu', 799000, 2, '/static/images/ao-khoac-nu-nhe.jpg', FALSE),
('Quần Jean Nam Xanh', 'Quần jean nam màu xanh, form slim fit', 699000, 3, '/static/images/quan-jean-nam-xanh.jpg', TRUE),
('Quần Kaki Nam Nâu', 'Quần kaki nam màu nâu, phong cách lịch lãm', 599000, 3, '/static/images/quan-kaki-nam-nau.jpg', FALSE),
('Quần Jean Nữ Xanh Nhạt', 'Quần jean nữ màu xanh nhạt, thiết kế hiện đại', 649000, 4, '/static/images/quan-jean-nu-xanh-nhat.jpg', TRUE),
('Váy Đầm Suông Đen', 'Váy đầm suông màu đen, thanh lịch', 899000, 5, '/static/images/vay-dam-suong-den.jpg', TRUE),
('Áo Polo Nam', 'Áo polo nam, phong cách thể thao', 399000, 1, '/static/images/1.jpg', FALSE),
('Áo Blazer Nữ', 'Áo blazer nữ, phong cách công sở', 1299000, 2, '/static/images/2.jpg', FALSE),
('Quần Short Nam', 'Quần short nam, thoải mái mùa hè', 349000, 3, '/static/images/3.jpg', FALSE),
('Chân Váy Nữ', 'Chân váy nữ, phong cách trẻ trung', 459000, 4, '/static/images/4.jpg', FALSE),
('Đầm Maxi', 'Đầm maxi dài, thanh lịch', 1199000, 5, '/static/images/5.jpg', FALSE),
('Áo Hoodie Nam', 'Áo hoodie nam, ấm áp mùa đông', 699000, 1, '/static/images/6.jpg', FALSE),
('Áo Cardigan Nữ', 'Áo cardigan nữ, phong cách vintage', 799000, 2, '/static/images/7.jpg', FALSE),
('Quần Jogger Nam', 'Quần jogger nam, thoải mái', 499000, 3, '/static/images/8.jpg', FALSE),
('Quần Legging Nữ', 'Quần legging nữ, co giãn tốt', 299000, 4, '/static/images/9.jpg', FALSE),
('Đầm Cocktail', 'Đầm cocktail, sang trọng', 1599000, 5, '/static/images/10.jpg', FALSE),
('Túi Xách Nữ', 'Túi xách nữ, thời trang', 899000, 6, '/static/images/11.jpg', FALSE),
('Ví Nam', 'Ví nam, da thật', 399000, 6, '/static/images/12.jpg', FALSE),
('Thắt Lưng Nam', 'Thắt lưng nam, da cao cấp', 299000, 6, '/static/images/13.jpg', FALSE);

-- Tạo các biến thể sản phẩm
INSERT INTO product_variants (product_id, color_id, size_id, stock_quantity, sku) VALUES
-- Áo Thun Nam Đen
(1, 1, 2, 50, 'ATN-DEN-S'),
(1, 1, 3, 75, 'ATN-DEN-M'),
(1, 1, 4, 60, 'ATN-DEN-L'),
(1, 1, 5, 40, 'ATN-DEN-XL'),
-- Áo Sơ Mi Nam Trắng
(2, 2, 2, 30, 'ASM-TRA-S'),
(2, 2, 3, 45, 'ASM-TRA-M'),
(2, 2, 4, 35, 'ASM-TRA-L'),
(2, 2, 5, 25, 'ASM-TRA-XL'),
-- Áo Thun Nữ Hồng
(3, 5, 1, 40, 'ATN-HON-XS'),
(3, 5, 2, 55, 'ATN-HON-S'),
(3, 5, 3, 45, 'ATN-HON-M'),
(3, 5, 4, 30, 'ATN-HON-L'),
-- Áo Sơ Mi Nữ Trắng
(4, 2, 1, 25, 'ASN-TRA-XS'),
(4, 2, 2, 40, 'ASN-TRA-S'),
(4, 2, 3, 35, 'ASN-TRA-M'),
(4, 2, 4, 20, 'ASN-TRA-L'),
-- Áo Khoác Nữ Nhẹ
(5, 7, 2, 20, 'AKN-XAM-S'),
(5, 7, 3, 25, 'AKN-XAM-M'),
(5, 7, 4, 15, 'AKN-XAM-L'),
-- Quần Jean Nam Xanh
(6, 3, 7, 30, 'QJN-XAN-28'),
(6, 3, 8, 40, 'QJN-XAN-29'),
(6, 3, 9, 45, 'QJN-XAN-30'),
(6, 3, 10, 35, 'QJN-XAN-31'),
(6, 3, 11, 25, 'QJN-XAN-32'),
-- Quần Kaki Nam Nâu
(7, 6, 7, 25, 'QKN-NAU-28'),
(7, 6, 8, 35, 'QKN-NAU-29'),
(7, 6, 9, 40, 'QKN-NAU-30'),
(7, 6, 10, 30, 'QKN-NAU-31'),
-- Quần Jean Nữ Xanh Nhạt
(8, 4, 7, 35, 'QJN-XNH-28'),
(8, 4, 8, 45, 'QJN-XNH-29'),
(8, 4, 9, 40, 'QJN-XNH-30'),
(8, 4, 10, 25, 'QJN-XNH-31'),
-- Váy Đầm Suông Đen
(9, 1, 1, 20, 'VDS-DEN-XS'),
(9, 1, 2, 30, 'VDS-DEN-S'),
(9, 1, 3, 25, 'VDS-DEN-M'),
(9, 1, 4, 15, 'VDS-DEN-L'),
-- Các sản phẩm khác
(10, 3, 3, 40, 'APO-XAN-M'),
(10, 2, 3, 35, 'APO-TRA-M'),
(11, 1, 2, 25, 'ABL-DEN-S'),
(11, 7, 2, 20, 'ABL-XAM-S'),
(12, 3, 9, 50, 'QSH-XAN-30'),
(12, 6, 9, 45, 'QSH-NAU-30'),
(13, 8, 2, 30, 'CVA-DOO-S'),
(13, 5, 2, 25, 'CVA-HON-S'),
(14, 2, 3, 20, 'DMA-TRA-M'),
(14, 1, 3, 15, 'DMA-DEN-M'),
(15, 7, 4, 35, 'AHO-XAM-L'),
(15, 1, 4, 30, 'AHO-DEN-L'),
(16, 6, 3, 40, 'ACA-NAU-M'),
(16, 1, 3, 35, 'ACA-DEN-M'),
(17, 1, 9, 60, 'QJO-DEN-30'),
(17, 7, 9, 55, 'QJO-XAM-30'),
(18, 1, 2, 45, 'QLE-DEN-S'),
(18, 7, 2, 40, 'QLE-XAM-S'),
(19, 8, 3, 15, 'DCO-DOO-M'),
(19, 1, 3, 12, 'DCO-DEN-M'),
(20, 6, 3, 25, 'TXA-NAU-M'),
(20, 1, 3, 20, 'TXA-DEN-M'),
(21, 6, 3, 30, 'VIN-NAU-M'),
(21, 1, 3, 25, 'VIN-DEN-M'),
(22, 6, 3, 35, 'TLU-NAU-M'),
(22, 1, 3, 30, 'TLU-DEN-M');

-- Tạo người dùng mẫu (mật khẩu: password123)
INSERT INTO users (username, email, password_hash, full_name, phone, address, is_admin, dark_mode) VALUES
('admin', 'admin@fashionstore.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Quản trị viên', '0123456789', 'Hà Nội', TRUE, FALSE),
('nguyenvana', 'nguyenvana@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Nguyễn Văn A', '0987654321', '123 Đường ABC, Hà Nội', FALSE, FALSE),
('tranthib', 'tranthib@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Trần Thị B', '0912345678', '456 Đường XYZ, TP.HCM', FALSE, TRUE),
('lequangc', 'lequangc@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Lê Quang C', '0934567890', '789 Đường DEF, Đà Nẵng', FALSE, FALSE),
('phamthid', 'phamthid@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Phạm Thị D', '0945678901', '321 Đường GHI, Hải Phòng', FALSE, TRUE),
('hoangvane', 'hoangvane@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Hoàng Văn E', '0956789012', '654 Đường JKL, Cần Thơ', FALSE, FALSE),
('vuthif', 'vuthif@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Vũ Thị F', '0967890123', '987 Đường MNO, Huế', FALSE, FALSE),
('dangvang', 'dangvang@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Đặng Văn G', '0978901234', '147 Đường PQR, Nha Trang', FALSE, TRUE),
('buithih', 'buithih@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Bùi Thị H', '0989012345', '258 Đường STU, Vũng Tàu', FALSE, FALSE),
('dovani', 'dovani@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Đỗ Văn I', '0990123456', '369 Đường VWX, Quy Nhon', FALSE, FALSE),
('ngothij', 'ngothij@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Ngô Thị J', '0901234567', '741 Đường YZ1, Pleiku', FALSE, TRUE),
('lyvanK', 'lyvanK@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Lý Văn K', '0912345670', '852 Đường AB2, Buôn Ma Thuột', FALSE, FALSE),
('duongthil', 'duongthil@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Dương Thị L', '0923456781', '963 Đường CD3, Phan Thiết', FALSE, FALSE),
('tranvanm', 'tranvanm@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Trần Văn M', '0934567892', '174 Đường EF4, Rạch Giá', FALSE, TRUE),
('lethinn', 'lethinn@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Lê Thị N', '0945678903', '285 Đường GH5, Cà Mau', FALSE, FALSE),
('phanvano', 'phanvano@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Phan Văn O', '0956789014', '396 Đường IJ6, Sóc Trăng', FALSE, FALSE),
('nguyenthip', 'nguyenthip@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Nguyễn Thị P', '0967890125', '407 Đường KL7, An Giang', FALSE, TRUE),
('truongvanq', 'truongvanq@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Trương Văn Q', '0978901236', '518 Đường MN8, Kiên Giang', FALSE, FALSE),
('vothir', 'vothir@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Võ Thị R', '0989012347', '629 Đường OP9, Bạc Liêu', FALSE, FALSE),
('dinhvans', 'dinhvans@email.com', 'scrypt:32768:8:1$salt$hashedpassword', 'Đinh Văn S', '0990123458', '730 Đường QR0, Hậu Giang', FALSE, TRUE);

-- Tạo đơn hàng mẫu
INSERT INTO orders (user_id, total_amount, status, shipping_address, phone, notes) VALUES
(2, 898000, 'completed', '123 Đường ABC, Hà Nội', '0987654321', 'Giao hàng giờ hành chính'),
(3, 1148000, 'shipped', '456 Đường XYZ, TP.HCM', '0912345678', 'Gọi trước khi giao'),
(4, 699000, 'processing', '789 Đường DEF, Đà Nẵng', '0934567890', ''),
(5, 1498000, 'pending', '321 Đường GHI, Hải Phòng', '0945678901', 'Thanh toán khi nhận hàng'),
(6, 799000, 'completed', '654 Đường JKL, Cần Thơ', '0956789012', ''),
(7, 948000, 'cancelled', '987 Đường MNO, Huế', '0967890123', 'Khách hủy đơn'),
(8, 649000, 'completed', '147 Đường PQR, Nha Trang', '0978901234', ''),
(9, 1798000, 'shipped', '258 Đường STU, Vũng Tàu', '0989012345', 'Giao cuối tuần'),
(10, 399000, 'processing', '369 Đường VWX, Quy Nhon', '0990123456', ''),
(11, 1299000, 'completed', '741 Đường YZ1, Pleiku', '0901234567', ''),
(12, 698000, 'pending', '852 Đường AB2, Buôn Ma Thuột', '0912345670', ''),
(13, 459000, 'completed', '963 Đường CD3, Phan Thiết', '0923456781', ''),
(14, 1199000, 'shipped', '174 Đường EF4, Rạch Giá', '0934567892', ''),
(15, 699000, 'processing', '285 Đường GH5, Cà Mau', '0945678903', ''),
(16, 1598000, 'completed', '396 Đường IJ6, Sóc Trăng', '0956789014', 'Giao nhanh'),
(17, 499000, 'pending', '407 Đường KL7, An Giang', '0967890125', ''),
(18, 299000, 'completed', '518 Đường MN8, Kiên Giang', '0978901236', ''),
(19, 1599000, 'shipped', '629 Đường OP9, Bạc Liêu', '0989012347', ''),
(20, 1198000, 'processing', '730 Đường QR0, Hậu Giang', '0990123458', '');

-- Chi tiết đơn hàng
INSERT INTO order_items (order_id, product_id, variant_id, quantity, price) VALUES
-- Đơn hàng 1
(1, 1, 2, 2, 299000),
(1, 2, 6, 1, 599000),
-- Đơn hàng 2
(2, 3, 10, 1, 259000),
(2, 4, 14, 1, 549000),
(2, 5, 17, 1, 799000),
-- Đơn hàng 3
(3, 6, 20, 1, 699000),
-- Đơn hàng 4
(4, 7, 25, 1, 599000),
(4, 8, 28, 1, 649000),
(4, 9, 31, 1, 899000),
-- Đơn hàng 5
(5, 5, 17, 1, 799000),
-- Đơn hàng 6
(6, 1, 3, 2, 299000),
(6, 10, 33, 1, 399000),
-- Đơn hàng 7
(7, 8, 29, 1, 649000),
-- Đơn hàng 8
(8, 9, 32, 2, 899000),
-- Đơn hàng 9
(9, 10, 34, 1, 399000),
-- Đơn hàng 10
(10, 11, 35, 1, 1299000),
-- Đơn hàng 11
(11, 12, 37, 2, 349000),
-- Đơn hàng 12
(12, 13, 39, 1, 459000),
-- Đơn hàng 13
(13, 14, 41, 1, 1199000),
-- Đơn hàng 14
(14, 15, 43, 1, 699000),
-- Đơn hàng 15
(15, 16, 45, 2, 799000),
-- Đơn hàng 16
(16, 17, 47, 1, 499000),
-- Đơn hàng 17
(17, 18, 49, 1, 299000),
-- Đơn hàng 18
(18, 19, 51, 1, 1599000),
-- Đơn hàng 19
(19, 20, 53, 1, 899000),
(19, 21, 55, 1, 399000);

-- Đánh giá sản phẩm
INSERT INTO reviews (user_id, product_id, rating, comment) VALUES
(2, 1, 5, 'Áo rất đẹp và chất lượng tốt!'),
(3, 2, 4, 'Áo sơ mi đẹp nhưng hơi đắt'),
(4, 6, 5, 'Quần jean rất vừa vặn và bền'),
(5, 9, 4, 'Váy đẹp nhưng hơi dài'),
(6, 5, 3, 'Áo khoác bình thường'),
(7, 8, 5, 'Quần jean nữ rất đẹp!'),
(8, 1, 4, 'Chất lượng tốt, giao hàng nhanh'),
(9, 3, 5, 'Màu sắc đẹp, form áo vừa vặn'),
(10, 10, 4, 'Áo polo đẹp, phù hợp đi chơi'),
(11, 11, 5, 'Áo blazer sang trọng, rất hài lòng'),
(12, 12, 3, 'Quần short bình thường'),
(13, 13, 4, 'Chân váy đẹp, phù hợp đi làm'),
(14, 14, 5, 'Đầm maxi rất đẹp và thanh lịch'),
(15, 15, 4, 'Áo hoodie ấm và thoải mái'),
(16, 16, 5, 'Áo cardigan phong cách vintage rất đẹp'),
(17, 17, 4, 'Quần jogger thoải mái khi vận động'),
(18, 18, 3, 'Quần legging bình thường'),
(19, 19, 5, 'Đầm cocktail rất sang trọng'),
(20, 20, 4, 'Túi xách đẹp và tiện dụng'),
(2, 21, 5, 'Ví nam chất lượng da tốt');

-- Danh sách yêu thích
INSERT INTO wishlist (user_id, product_id) VALUES
(2, 3), (2, 5), (2, 9),
(3, 1), (3, 6), (3, 11),
(4, 2), (4, 7), (4, 12),
(5, 4), (5, 8), (5, 13),
(6, 10), (6, 14), (6, 15),
(7, 16), (7, 17), (7, 18),
(8, 19), (8, 20), (8, 21);

-- Bình luận sản phẩm
INSERT INTO product_comments (user_id, product_id, comment, is_approved) VALUES
(2, 1, 'Áo này có màu nào khác không?', TRUE),
(3, 1, 'Chất liệu cotton rất thoáng mát', TRUE),
(4, 2, 'Size M có vừa với người cao 1m7 không?', TRUE),
(5, 6, 'Quần có co giãn không?', TRUE),
(6, 9, 'Váy này phù hợp đi tiệc không?', TRUE),
(7, 3, 'Màu hồng có đậm không?', TRUE),
(8, 4, 'Áo có nhăn không khi giặt?', TRUE),
(9, 5, 'Áo khoác có chống nước không?', TRUE),
(10, 7, 'Quần kaki có bền không?', TRUE),
(11, 8, 'Form quần có ôm không?', TRUE),
(12, 10, 'Áo polo có nhiều màu không?', TRUE),
(13, 11, 'Blazer có lót trong không?', TRUE),
(14, 12, 'Quần short có túi không?', TRUE),
(15, 13, 'Chân váy có dây kéo không?', TRUE),
(16, 14, 'Đầm có size nhỏ hơn không?', TRUE),
(17, 15, 'Hoodie có mũ không?', TRUE),
(18, 16, 'Cardigan có cúc không?', TRUE),
(19, 17, 'Quần jogger có dây rút không?', TRUE),
(20, 18, 'Legging có độ dày như thế nào?', TRUE),
(2, 19, 'Đầm cocktail có nhiều size không?', TRUE);

-- Tin nhắn liên hệ
INSERT INTO contact_messages (name, email, subject, message, is_read) VALUES
('Nguyễn Văn A', 'nguyenvana@email.com', 'Hỏi về sản phẩm', 'Tôi muốn hỏi về chất lượng áo thun', FALSE),
('Trần Thị B', 'tranthib@email.com', 'Đổi trả hàng', 'Làm sao để đổi size áo?', TRUE),
('Lê Quang C', 'lequangc@email.com', 'Giao hàng', 'Bao lâu thì giao hàng đến Đà Nẵng?', FALSE),
('Phạm Thị D', 'phamthid@email.com', 'Thanh toán', 'Có thể thanh toán bằng thẻ tín dụng không?', TRUE),
('Hoàng Văn E', 'hoangvane@email.com', 'Khuyến mãi', 'Khi nào có chương trình giảm giá?', FALSE),
('Vũ Thị F', 'vuthif@email.com', 'Size áo', 'Làm sao để chọn size phù hợp?', TRUE),
('Đặng Văn G', 'dangvang@email.com', 'Chất lượng', 'Sản phẩm có bảo hành không?', FALSE),
('Bùi Thị H', 'buithih@email.com', 'Đặt hàng', 'Tôi không thể đặt hàng được', TRUE),
('Đỗ Văn I', 'dovani@email.com', 'Tài khoản', 'Quên mật khẩu tài khoản', FALSE),
('Ngô Thị J', 'ngothij@email.com', 'Sản phẩm mới', 'Khi nào có sản phẩm mới?', TRUE),
('Lý Văn K', 'lyvanK@email.com', 'Phí ship', 'Phí giao hàng là bao nhiêu?', FALSE),
('Dương Thị L', 'duongthil@email.com', 'Màu sắc', 'Sản phẩm có màu nào khác không?', TRUE),
('Trần Văn M', 'tranvanm@email.com', 'Số lượng', 'Còn hàng size L không?', FALSE),
('Lê Thị N', 'lethinn@email.com', 'Chăm sóc', 'Cách bảo quản sản phẩm?', TRUE),
('Phan Văn O', 'phanvano@email.com', 'Đánh giá', 'Làm sao để đánh giá sản phẩm?', FALSE),
('Nguyễn Thị P', 'nguyenthip@email.com', 'Ưu đãi', 'Có ưu đãi cho khách hàng thân thiết không?', TRUE),
('Trương Văn Q', 'truongvanq@email.com', 'Liên hệ', 'Số điện thoại liên hệ là gì?', FALSE),
('Võ Thị R', 'vothir@email.com', 'Website', 'Website có app mobile không?', TRUE),
('Đinh Văn S', 'dinhvans@email.com', 'Góp ý', 'Tôi có góp ý về giao diện website', FALSE),
('Nguyễn Văn T', 'nguyenvant@email.com', 'Hợp tác', 'Muốn hợp tác kinh doanh', TRUE);

-- Đăng ký nhận tin
INSERT INTO newsletter_subscribers (email, is_active) VALUES
('subscriber1@email.com', TRUE),
('subscriber2@email.com', TRUE),
('subscriber3@email.com', FALSE),
('subscriber4@email.com', TRUE),
('subscriber5@email.com', TRUE),
('subscriber6@email.com', TRUE),
('subscriber7@email.com', FALSE),
('subscriber8@email.com', TRUE),
('subscriber9@email.com', TRUE),
('subscriber10@email.com', TRUE),
('subscriber11@email.com', TRUE),
('subscriber12@email.com', FALSE),
('subscriber13@email.com', TRUE),
('subscriber14@email.com', TRUE),
('subscriber15@email.com', TRUE),
('subscriber16@email.com', TRUE),
('subscriber17@email.com', FALSE),
('subscriber18@email.com', TRUE),
('subscriber19@email.com', TRUE),
('subscriber20@email.com', TRUE),
('subscriber21@email.com', TRUE),
('subscriber22@email.com', FALSE),
('subscriber23@email.com', TRUE),
('subscriber24@email.com', TRUE),
('subscriber25@email.com', TRUE),
('subscriber26@email.com', TRUE),
('subscriber27@email.com', FALSE),
('subscriber28@email.com', TRUE),
('subscriber29@email.com', TRUE),
('subscriber30@email.com', TRUE);

-- Sản phẩm đã xem gần đây
INSERT INTO recently_viewed (user_id, product_id, viewed_at) VALUES
(2, 1, NOW() - INTERVAL '1 hour'),
(2, 3, NOW() - INTERVAL '2 hours'),
(2, 5, NOW() - INTERVAL '3 hours'),
(3, 2, NOW() - INTERVAL '30 minutes'),
(3, 4, NOW() - INTERVAL '1 hour'),
(3, 6, NOW() - INTERVAL '2 hours'),
(4, 7, NOW() - INTERVAL '45 minutes'),
(4, 8, NOW() - INTERVAL '1.5 hours'),
(4, 9, NOW() - INTERVAL '3 hours'),
(5, 10, NOW() - INTERVAL '20 minutes'),
(5, 11, NOW() - INTERVAL '1 hour'),
(5, 12, NOW() - INTERVAL '2.5 hours');

-- Tạo trigger để tự động cập nhật tổng tiền đơn hàng
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE orders 
    SET total_amount = (
        SELECT COALESCE(SUM(quantity * price), 0)
        FROM order_items 
        WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
    )
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_order_total
    AFTER INSERT OR UPDATE OR DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_order_total();

-- Tạo view thống kê doanh thu theo tháng
CREATE OR REPLACE VIEW monthly_revenue AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM orders 
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- Tạo view sản phẩm bán chạy
CREATE OR REPLACE VIEW best_selling_products AS
SELECT 
    p.id,
    p.name,
    p.price,
    p.image_url,
    SUM(oi.quantity) as total_sold,
    SUM(oi.quantity * oi.price) as total_revenue
FROM products p
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'completed'
GROUP BY p.id, p.name, p.price, p.image_url
ORDER BY total_sold DESC;

-- Tạo view thống kê khách hàng
CREATE OR REPLACE VIEW customer_stats AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.full_name,
    COUNT(o.id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    COALESCE(AVG(o.total_amount), 0) as avg_order_value,
    MAX(o.created_at) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.status = 'completed'
WHERE u.is_admin = FALSE
GROUP BY u.id, u.username, u.email, u.full_name
ORDER BY total_spent DESC;

-- Tạo các chỉ mục để tối ưu hiệu suất
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_featured ON products(is_featured);
CREATE INDEX IF NOT EXISTS idx_product_variants_product ON product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_user ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_product ON wishlist(product_id);
CREATE INDEX IF NOT EXISTS idx_comments_product ON product_comments(product_id);
CREATE INDEX IF NOT EXISTS idx_comments_approved ON product_comments(is_approved);
CREATE INDEX IF NOT EXISTS idx_recently_viewed_user ON recently_viewed(user_id);
CREATE INDEX IF NOT EXISTS idx_recently_viewed_time ON recently_viewed(viewed_at);