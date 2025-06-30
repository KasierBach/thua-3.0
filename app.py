from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import os
from datetime import datetime, timedelta
import decimal
import json
import re
import uuid
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'fashion_store_secret_key_development')

# Cấu hình SQLite database
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{os.path.join(basedir, "fashion_store.db")}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Cấu hình email
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', 'your_email@gmail.com')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', 'your_app_password')
EMAIL_USE_TLS = True

db = SQLAlchemy(app)

# Models
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(100))
    phone = db.Column(db.String(20))
    address = db.Column(db.Text)
    is_admin = db.Column(db.Boolean, default=False)
    dark_mode = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Category(db.Model):
    __tablename__ = 'categories'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    image_url = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Color(db.Model):
    __tablename__ = 'colors'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), nullable=False)
    hex_code = db.Column(db.String(7))

class Size(db.Model):
    __tablename__ = 'sizes'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(10), nullable=False)
    description = db.Column(db.String(50))

class Product(db.Model):
    __tablename__ = 'products'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text)
    base_price = db.Column(db.Numeric(10, 2), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))
    image_url = db.Column(db.String(255))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    category = db.relationship('Category', backref='products')

class ProductVariant(db.Model):
    __tablename__ = 'product_variants'
    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id', ondelete='CASCADE'))
    color_id = db.Column(db.Integer, db.ForeignKey('colors.id'))
    size_id = db.Column(db.Integer, db.ForeignKey('sizes.id'))
    price = db.Column(db.Numeric(10, 2), nullable=False)
    stock_quantity = db.Column(db.Integer, default=0)
    sku = db.Column(db.String(100), unique=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    product = db.relationship('Product', backref='variants')
    color = db.relationship('Color')
    size = db.relationship('Size')

class Order(db.Model):
    __tablename__ = 'orders'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    total_amount = db.Column(db.Numeric(10, 2), default=0)
    status = db.Column(db.String(20), default='pending')
    shipping_address = db.Column(db.Text)
    phone = db.Column(db.String(20))
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    user = db.relationship('User', backref='orders')

class OrderDetail(db.Model):
    __tablename__ = 'order_details'
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id', ondelete='CASCADE'))
    product_variant_id = db.Column(db.Integer, db.ForeignKey('product_variants.id'))
    quantity = db.Column(db.Integer, nullable=False)
    unit_price = db.Column(db.Numeric(10, 2), nullable=False)
    total_price = db.Column(db.Numeric(10, 2), nullable=False)
    
    order = db.relationship('Order', backref='details')
    variant = db.relationship('ProductVariant')

class ProductReview(db.Model):
    __tablename__ = 'product_reviews'
    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id', ondelete='CASCADE'))
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    product = db.relationship('Product', backref='reviews')
    user = db.relationship('User')

class Wishlist(db.Model):
    __tablename__ = 'wishlist'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id', ondelete='CASCADE'))
    product_id = db.Column(db.Integer, db.ForeignKey('products.id', ondelete='CASCADE'))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (db.UniqueConstraint('user_id', 'product_id'),)
    
    user = db.relationship('User')
    product = db.relationship('Product')

class ProductComment(db.Model):
    __tablename__ = 'product_comments'
    id = db.Column(db.Integer, primary_key=True)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id', ondelete='CASCADE'))
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    comment = db.Column(db.Text, nullable=False)
    is_approved = db.Column(db.Boolean, default=False)
    admin_reply = db.Column(db.Text)
    reply_date = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    product = db.relationship('Product')
    user = db.relationship('User')

class ContactMessage(db.Model):
    __tablename__ = 'contact_messages'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    subject = db.Column(db.String(200))
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class NewsletterSubscription(db.Model):
    __tablename__ = 'newsletter_subscriptions'
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class PasswordResetToken(db.Model):
    __tablename__ = 'password_reset_tokens'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    token = db.Column(db.String(255), unique=True, nullable=False)
    expiry_date = db.Column(db.DateTime, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    user = db.relationship('User')

# Hàm chuyển đổi decimal sang float cho JSON
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            return float(o)
        return super(DecimalEncoder, self).default(o)

# Hàm gửi email
def send_email(to_email, subject, html_content):
    try:
        msg = MIMEMultipart()
        msg['From'] = EMAIL_HOST_USER
        msg['To'] = to_email
        msg['Subject'] = subject
        
        msg.attach(MIMEText(html_content, 'html'))
        
        server = smtplib.SMTP(EMAIL_HOST, EMAIL_PORT)
        server.starttls()
        server.login(EMAIL_HOST_USER, EMAIL_HOST_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception as e:
        print(f"Error sending email: {str(e)}")
        return False

# Khởi tạo database và dữ liệu mẫu
def init_db():
    with app.app_context():
        db.create_all()
        
        # Kiểm tra xem đã có dữ liệu chưa
        if User.query.first() is None:
            # Thêm màu sắc
            colors = [
                Color(name='Đen', hex_code='#000000'),
                Color(name='Trắng', hex_code='#FFFFFF'),
                Color(name='Xanh dương', hex_code='#0000FF'),
                Color(name='Đỏ', hex_code='#FF0000'),
                Color(name='Xanh lá', hex_code='#008000'),
                Color(name='Vàng', hex_code='#FFFF00'),
                Color(name='Hồng', hex_code='#FFC0CB'),
                Color(name='Nâu', hex_code='#A52A2A'),
                Color(name='Xám', hex_code='#808080')
            ]
            for color in colors:
                db.session.add(color)
            
            # Thêm kích thước
            sizes = [
                Size(name='XS', description='Extra Small'),
                Size(name='S', description='Small'),
                Size(name='M', description='Medium'),
                Size(name='L', description='Large'),
                Size(name='XL', description='Extra Large'),
                Size(name='XXL', description='Double Extra Large'),
                Size(name='28', description='Eo 28 inch'),
                Size(name='29', description='Eo 29 inch'),
                Size(name='30', description='Eo 30 inch'),
                Size(name='31', description='Eo 31 inch'),
                Size(name='32', description='Eo 32 inch'),
                Size(name='33', description='Eo 33 inch')
            ]
            for size in sizes:
                db.session.add(size)
            
            # Thêm danh mục
            categories = [
                Category(name='Áo Nam', description='Các loại áo dành cho nam giới', image_url='/static/images/ao-nam.jpg'),
                Category(name='Áo Nữ', description='Các loại áo dành cho nữ giới', image_url='/static/images/ao-nu.jpg'),
                Category(name='Quần Nam', description='Các loại quần dành cho nam giới', image_url='/static/images/quan-nam.jpg'),
                Category(name='Quần Nữ', description='Các loại quần dành cho nữ giới', image_url='/static/images/quan-nu.jpg'),
                Category(name='Váy Đầm', description='Các loại váy đầm nữ', image_url='/static/images/vay-dam.jpg'),
                Category(name='Phụ Kiện', description='Các loại phụ kiện thời trang', image_url='/static/images/phu-kien.jpg')
            ]
            for category in categories:
                db.session.add(category)
            
            db.session.commit()
            
            # Thêm sản phẩm
            products = [
                Product(name='Áo Thun Nam Đen', description='Áo thun nam màu đen, chất liệu cotton thoáng mát', base_price=299000, category_id=1, image_url='/static/images/ao-thun-nam-den.jpg'),
                Product(name='Áo Sơ Mi Nam Trắng', description='Áo sơ mi nam màu trắng, phù hợp đi làm', base_price=499000, category_id=1, image_url='/static/images/ao-so-mi-nam-trang.jpg'),
                Product(name='Áo Thun Nữ Hồng', description='Áo thun nữ màu hồng, thiết kế trẻ trung', base_price=259000, category_id=2, image_url='/static/images/ao-thun-nu-hong.jpg'),
                Product(name='Áo Sơ Mi Nữ Trắng', description='Áo sơ mi nữ màu trắng, thanh lịch', base_price=459000, category_id=2, image_url='/static/images/ao-so-mi-nu-trang.jpg'),
                Product(name='Áo Khoác Nữ Nhẹ', description='Áo khoác nữ nhẹ, phù hợp mùa thu', base_price=699000, category_id=2, image_url='/static/images/ao-khoac-nu-nhe.jpg'),
                Product(name='Quần Jean Nam Xanh', description='Quần jean nam màu xanh, form slim fit', base_price=599000, category_id=3, image_url='/static/images/quan-jean-nam-xanh.jpg'),
                Product(name='Quần Kaki Nam Nâu', description='Quần kaki nam màu nâu, phong cách lịch lãm', base_price=549000, category_id=3, image_url='/static/images/quan-kaki-nam-nau.jpg'),
                Product(name='Quần Jean Nữ Xanh Nhạt', description='Quần jean nữ màu xanh nhạt, form skinny', base_price=559000, category_id=4, image_url='/static/images/quan-jean-nu-xanh-nhat.jpg'),
                Product(name='Váy Đầm Suông Đen', description='Váy đầm suông màu đen, thanh lịch', base_price=799000, category_id=5, image_url='/static/images/vay-dam-suong-den.jpg')
            ]
            for product in products:
                db.session.add(product)
            
            db.session.commit()
            
            # Thêm biến thể sản phẩm
            variants = [
                # Áo Thun Nam Đen
                ProductVariant(product_id=1, color_id=1, size_id=2, price=299000, stock_quantity=50, sku='ATN-DEN-S'),
                ProductVariant(product_id=1, color_id=1, size_id=3, price=299000, stock_quantity=45, sku='ATN-DEN-M'),
                ProductVariant(product_id=1, color_id=1, size_id=4, price=299000, stock_quantity=40, sku='ATN-DEN-L'),
                ProductVariant(product_id=1, color_id=1, size_id=5, price=299000, stock_quantity=35, sku='ATN-DEN-XL'),
                # Áo Sơ Mi Nam Trắng
                ProductVariant(product_id=2, color_id=2, size_id=2, price=499000, stock_quantity=30, sku='ASM-TRA-S'),
                ProductVariant(product_id=2, color_id=2, size_id=3, price=499000, stock_quantity=25, sku='ASM-TRA-M'),
                ProductVariant(product_id=2, color_id=2, size_id=4, price=499000, stock_quantity=20, sku='ASM-TRA-L'),
                ProductVariant(product_id=2, color_id=2, size_id=5, price=499000, stock_quantity=15, sku='ASM-TRA-XL'),
                # Áo Thun Nữ Hồng
                ProductVariant(product_id=3, color_id=7, size_id=1, price=259000, stock_quantity=40, sku='ATN-HON-XS'),
                ProductVariant(product_id=3, color_id=7, size_id=2, price=259000, stock_quantity=35, sku='ATN-HON-S'),
                ProductVariant(product_id=3, color_id=7, size_id=3, price=259000, stock_quantity=30, sku='ATN-HON-M'),
                ProductVariant(product_id=3, color_id=7, size_id=4, price=259000, stock_quantity=25, sku='ATN-HON-L'),
                # Áo Sơ Mi Nữ Trắng
                ProductVariant(product_id=4, color_id=2, size_id=1, price=459000, stock_quantity=25, sku='ASN-TRA-XS'),
                ProductVariant(product_id=4, color_id=2, size_id=2, price=459000, stock_quantity=20, sku='ASN-TRA-S'),
                ProductVariant(product_id=4, color_id=2, size_id=3, price=459000, stock_quantity=18, sku='ASN-TRA-M'),
                ProductVariant(product_id=4, color_id=2, size_id=4, price=459000, stock_quantity=15, sku='ASN-TRA-L'),
                # Áo Khoác Nữ Nhẹ
                ProductVariant(product_id=5, color_id=1, size_id=2, price=699000, stock_quantity=20, sku='AKN-DEN-S'),
                ProductVariant(product_id=5, color_id=1, size_id=3, price=699000, stock_quantity=18, sku='AKN-DEN-M'),
                ProductVariant(product_id=5, color_id=1, size_id=4, price=699000, stock_quantity=15, sku='AKN-DEN-L'),
                ProductVariant(product_id=5, color_id=9, size_id=2, price=699000, stock_quantity=12, sku='AKN-XAM-S'),
                ProductVariant(product_id=5, color_id=9, size_id=3, price=699000, stock_quantity=10, sku='AKN-XAM-M'),
                # Quần Jean Nam Xanh
                ProductVariant(product_id=6, color_id=3, size_id=7, price=599000, stock_quantity=25, sku='QJN-XAN-28'),
                ProductVariant(product_id=6, color_id=3, size_id=8, price=599000, stock_quantity=22, sku='QJN-XAN-29'),
                ProductVariant(product_id=6, color_id=3, size_id=9, price=599000, stock_quantity=20, sku='QJN-XAN-30'),
                ProductVariant(product_id=6, color_id=3, size_id=10, price=599000, stock_quantity=18, sku='QJN-XAN-31'),
                ProductVariant(product_id=6, color_id=3, size_id=11, price=599000, stock_quantity=15, sku='QJN-XAN-32'),
                # Quần Kaki Nam Nâu
                ProductVariant(product_id=7, color_id=8, size_id=7, price=549000, stock_quantity=20, sku='QKN-NAU-28'),
                ProductVariant(product_id=7, color_id=8, size_id=8, price=549000, stock_quantity=18, sku='QKN-NAU-29'),
                ProductVariant(product_id=7, color_id=8, size_id=9, price=549000, stock_quantity=16, sku='QKN-NAU-30'),
                ProductVariant(product_id=7, color_id=8, size_id=10, price=549000, stock_quantity=14, sku='QKN-NAU-31'),
                ProductVariant(product_id=7, color_id=8, size_id=11, price=549000, stock_quantity=12, sku='QKN-NAU-32'),
                # Quần Jean Nữ Xanh Nhạt
                ProductVariant(product_id=8, color_id=3, size_id=1, price=559000, stock_quantity=18, sku='QJN-XAN-XS'),
                ProductVariant(product_id=8, color_id=3, size_id=2, price=559000, stock_quantity=16, sku='QJN-XAN-S'),
                ProductVariant(product_id=8, color_id=3, size_id=3, price=559000, stock_quantity=14, sku='QJN-XAN-M'),
                ProductVariant(product_id=8, color_id=3, size_id=4, price=559000, stock_quantity=12, sku='QJN-XAN-L'),
                # Váy Đầm Suông Đen
                ProductVariant(product_id=9, color_id=1, size_id=1, price=799000, stock_quantity=15, sku='VDS-DEN-XS'),
                ProductVariant(product_id=9, color_id=1, size_id=2, price=799000, stock_quantity=12, sku='VDS-DEN-S'),
                ProductVariant(product_id=9, color_id=1, size_id=3, price=799000, stock_quantity=10, sku='VDS-DEN-M'),
                ProductVariant(product_id=9, color_id=1, size_id=4, price=799000, stock_quantity=8, sku='VDS-DEN-L')
            ]
            for variant in variants:
                db.session.add(variant)
            
            # Thêm người dùng mẫu
            users = [
                User(username='admin', email='admin@fashionstore.com', password_hash=generate_password_hash('admin123'), full_name='Quản trị viên', phone='0123456789', address='Hà Nội', is_admin=True),
                User(username='user1', email='user1@email.com', password_hash=generate_password_hash('password123'), full_name='Nguyễn Văn A', phone='0987654321', address='TP.HCM'),
                User(username='user2', email='user2@email.com', password_hash=generate_password_hash('password123'), full_name='Trần Thị B', phone='0912345678', address='Đà Nẵng'),
                User(username='user3', email='user3@email.com', password_hash=generate_password_hash('password123'), full_name='Lê Văn C', phone='0934567890', address='Hải Phòng'),
                User(username='user4', email='user4@email.com', password_hash=generate_password_hash('password123'), full_name='Phạm Thị D', phone='0945678901', address='Cần Thơ')
            ]
            for user in users:
                db.session.add(user)
            
            db.session.commit()
            
            # Thêm đơn hàng mẫu
            orders = [
                Order(user_id=2, total_amount=598000, status='completed', shipping_address='TP.HCM', phone='0987654321'),
                Order(user_id=3, total_amount=1158000, status='processing', shipping_address='Đà Nẵng', phone='0912345678'),
                Order(user_id=4, total_amount=799000, status='pending', shipping_address='Hải Phòng', phone='0934567890'),
                Order(user_id=5, total_amount=1098000, status='completed', shipping_address='Cần Thơ', phone='0945678901')
            ]
            for order in orders:
                db.session.add(order)
            
            db.session.commit()
            
            # Thêm chi tiết đơn hàng
            order_details = [
                OrderDetail(order_id=1, product_variant_id=1, quantity=2, unit_price=299000, total_price=598000),
                OrderDetail(order_id=2, product_variant_id=13, quantity=1, unit_price=459000, total_price=459000),
                OrderDetail(order_id=2, product_variant_id=17, quantity=1, unit_price=699000, total_price=699000),
                OrderDetail(order_id=3, product_variant_id=33, quantity=1, unit_price=799000, total_price=799000),
                OrderDetail(order_id=4, product_variant_id=6, quantity=1, unit_price=499000, total_price=499000),
                OrderDetail(order_id=4, product_variant_id=21, quantity=1, unit_price=599000, total_price=599000)
            ]
            for detail in order_details:
                db.session.add(detail)
            
            # Thêm đánh giá sản phẩm
            reviews = [
                ProductReview(product_id=1, user_id=2, rating=5, comment='Áo rất đẹp và chất lượng tốt'),
                ProductReview(product_id=2, user_id=3, rating=4, comment='Áo sơ mi đẹp, phù hợp đi làm'),
                ProductReview(product_id=3, user_id=4, rating=5, comment='Màu hồng rất xinh, chất liệu mềm mại'),
                ProductReview(product_id=9, user_id=5, rating=4, comment='Váy đẹp nhưng hơi dài')
            ]
            for review in reviews:
                db.session.add(review)
            
            # Thêm wishlist
            wishlists = [
                Wishlist(user_id=2, product_id=3),
                Wishlist(user_id=2, product_id=5),
                Wishlist(user_id=2, product_id=9),
                Wishlist(user_id=3, product_id=1),
                Wishlist(user_id=3, product_id=6),
                Wishlist(user_id=4, product_id=2),
                Wishlist(user_id=4, product_id=4),
                Wishlist(user_id=4, product_id=8),
                Wishlist(user_id=5, product_id=7),
                Wishlist(user_id=5, product_id=9)
            ]
            for wishlist in wishlists:
                db.session.add(wishlist)
            
            # Thêm bình luận sản phẩm
            comments = [
                ProductComment(product_id=1, user_id=2, comment='Áo này có màu nào khác không?', is_approved=True),
                ProductComment(product_id=2, user_id=3, comment='Size M có vừa với người cao 1m7 không?', is_approved=True),
                ProductComment(product_id=3, user_id=4, comment='Chất liệu có co giãn không?', is_approved=False),
                ProductComment(product_id=9, user_id=5, comment='Váy này có thể giặt máy được không?', is_approved=True)
            ]
            for comment in comments:
                db.session.add(comment)
            
            # Thêm tin nhắn liên hệ
            messages = [
                ContactMessage(name='Nguyễn Văn E', email='user5@email.com', subject='Hỏi về sản phẩm', message='Tôi muốn hỏi về chính sách đổi trả'),
                ContactMessage(name='Trần Thị F', email='user6@email.com', subject='Khiếu nại', message='Sản phẩm tôi nhận không đúng màu'),
                ContactMessage(name='Lê Văn G', email='user7@email.com', subject='Góp ý', message='Website rất đẹp và dễ sử dụng')
            ]
            for message in messages:
                db.session.add(message)
            
            # Thêm đăng ký newsletter
            newsletters = [
                NewsletterSubscription(email='newsletter1@email.com'),
                NewsletterSubscription(email='newsletter2@email.com'),
                NewsletterSubscription(email='newsletter3@email.com'),
                NewsletterSubscription(email='newsletter4@email.com'),
                NewsletterSubscription(email='newsletter5@email.com')
            ]
            for newsletter in newsletters:
                db.session.add(newsletter)
            
            db.session.commit()
            print("Database initialized with sample data!")

# Routes

# Trang chủ
@app.route('/')
def home():
    categories = Category.query.all()
    featured_products = Product.query.filter_by(is_active=True).limit(8).all()
    
    # Lấy sản phẩm bán chạy (giả lập)
    best_selling = Product.query.filter_by(is_active=True).limit(6).all()
    
    return render_template('index.html', 
                          categories=categories, 
                          featured_products=featured_products,
                          best_selling=best_selling)

# Trang danh sách sản phẩm
@app.route('/products')
def products():
    category_id = request.args.get('category', type=int)
    search_term = request.args.get('search', '')
    min_price = request.args.get('min_price', type=float)
    max_price = request.args.get('max_price', type=float)
    color_id = request.args.get('color', type=int)
    size_id = request.args.get('size', type=int)
    
    categories = Category.query.all()
    colors = Color.query.all()
    sizes = Size.query.all()
    
    # Tạo query cơ bản
    query = Product.query.filter_by(is_active=True)
    
    # Áp dụng các bộ lọc
    if category_id:
        query = query.filter_by(category_id=category_id)
    
    if search_term:
        query = query.filter(Product.name.contains(search_term))
    
    if min_price:
        query = query.filter(Product.base_price >= min_price)
    
    if max_price:
        query = query.filter(Product.base_price <= max_price)
    
    products = query.all()
    
    return render_template('products.html', 
                          products=products, 
                          categories=categories,
                          colors=colors,
                          sizes=sizes,
                          current_category=category_id,
                          search_term=search_term)

# Trang chi tiết sản phẩm
@app.route('/product/<int:product_id>')
def product_detail(product_id):
    product = Product.query.get_or_404(product_id)
    
    # Lấy các biến thể của sản phẩm
    variants = ProductVariant.query.filter_by(product_id=product_id).all()
    
    # Tổ chức các biến thể theo màu sắc và kích thước
    colors = {}
    sizes = {}
    variants_map = {}
    
    for variant in variants:
        color_id = variant.color_id
        size_id = variant.size_id
        
        if color_id not in colors:
            colors[color_id] = {'id': color_id, 'name': variant.color.name}
        
        if size_id not in sizes:
            sizes[size_id] = {'id': size_id, 'name': variant.size.name}
        
        key = f"{color_id}_{size_id}"
        variants_map[key] = {
            'variant_id': variant.id,
            'quantity': variant.stock_quantity,
            'price': float(variant.price)
        }
    
    # Lấy đánh giá sản phẩm
    reviews = ProductReview.query.filter_by(product_id=product_id).all()
    
    # Tính rating breakdown
    rating_breakdown = {i: 0 for i in range(1, 6)}
    for review in reviews:
        rating_breakdown[review.rating] += 1
    
    return render_template('product_detail.html', 
                          product=product,
                          original_price=float(product.base_price) * 1.2,
                          colors=list(colors.values()),
                          sizes=list(sizes.values()),
                          variants=variants_map,
                          rating_breakdown=rating_breakdown,
                          reviews=reviews)

# Thêm vào giỏ hàng
@app.route('/add_to_cart', methods=['POST'])
def add_to_cart():
    variant_id = request.form.get('variant_id', type=int)
    quantity = request.form.get('quantity', type=int, default=1)
    
    if not variant_id:
        flash('Vui lòng chọn màu sắc và kích thước', 'error')
        return redirect(request.referrer)
    
    # Kiểm tra số lượng tồn kho
    variant = ProductVariant.query.get_or_404(variant_id)
    
    if variant.stock_quantity < quantity:
        flash(f'Chỉ còn {variant.stock_quantity} sản phẩm trong kho', 'error')
        return redirect(request.referrer)
    
    # Khởi tạo giỏ hàng nếu chưa có
    if 'cart' not in session:
        session['cart'] = []
    
    # Kiểm tra xem sản phẩm đã có trong giỏ hàng chưa
    cart = session['cart']
    found = False
    
    for item in cart:
        if item['variant_id'] == variant_id:
            item['quantity'] += quantity
            found = True
            break
    
    # Nếu chưa có, thêm mới vào giỏ hàng
    if not found:
        cart.append({
            'variant_id': variant_id,
            'product_id': variant.product_id,
            'product_name': variant.product.name,
            'price': float(variant.price),
            'color': variant.color.name,
            'size': variant.size.name,
            'quantity': quantity,
            'image_url': variant.product.image_url
        })
    
    session['cart'] = cart
    flash('Đã thêm sản phẩm vào giỏ hàng', 'success')
    return redirect(request.referrer)

# Trang giỏ hàng
@app.route('/cart')
def view_cart():
    cart = session.get('cart', [])
    total = sum(item['price'] * item['quantity'] for item in cart)
    
    return render_template('cart.html', cart=cart, total=total)

# Mua ngay
@app.route('/buy_now', methods=['POST'])
def buy_now():
    variant_id = request.form.get('variant_id', type=int)
    quantity = request.form.get('quantity', type=int, default=1)
    
    if not variant_id:
        flash('Vui lòng chọn màu sắc và kích thước', 'error')
        return redirect(request.referrer)
    
    # Kiểm tra số lượng tồn kho
    variant = ProductVariant.query.get_or_404(variant_id)
    
    if variant.stock_quantity < quantity:
        flash(f'Chỉ còn {variant.stock_quantity} sản phẩm trong kho', 'error')
        return redirect(request.referrer)
    
    # Tạo giỏ hàng tạm thời cho phiên mua ngay
    temp_cart = [{
        'variant_id': variant_id,
        'product_id': variant.product_id,
        'product_name': variant.product.name,
        'price': float(variant.price),
        'color': variant.color.name,
        'size': variant.size.name,
        'quantity': quantity,
        'image_url': variant.product.image_url
    }]
    
    # Lưu giỏ hàng tạm thời vào session
    session['temp_cart'] = temp_cart
    
    # Chuyển hướng đến trang thanh toán
    return redirect(url_for('checkout', buy_now=1))

# Cập nhật giỏ hàng
@app.route('/update_cart', methods=['POST'])
def update_cart():
    variant_id = request.form.get('variant_id', type=int)
    quantity = request.form.get('quantity', type=int)
    
    if not variant_id or quantity < 1:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    # Kiểm tra số lượng tồn kho
    variant = ProductVariant.query.get(variant_id)
    if not variant or variant.stock_quantity < quantity:
        return jsonify({'success': False, 'message': f'Chỉ còn {variant.stock_quantity if variant else 0} sản phẩm trong kho'})
    
    # Cập nhật giỏ hàng
    cart = session.get('cart', [])
    for item in cart:
        if item['variant_id'] == variant_id:
            item['quantity'] = quantity
            break
    
    session['cart'] = cart
    total = sum(item['price'] * item['quantity'] for item in cart)
    
    return jsonify({
        'success': True, 
        'message': 'Đã cập nhật giỏ hàng',
        'total': total
    })

# Xóa sản phẩm khỏi giỏ hàng
@app.route('/remove_from_cart', methods=['POST'])
def remove_from_cart():
    variant_id = request.form.get('variant_id', type=int)
    
    if not variant_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    # Xóa sản phẩm khỏi giỏ hàng
    cart = session.get('cart', [])
    cart = [item for item in cart if item['variant_id'] != variant_id]
    session['cart'] = cart
    
    total = sum(item['price'] * item['quantity'] for item in cart)
    
    return jsonify({
        'success': True, 
        'message': 'Đã xóa sản phẩm khỏi giỏ hàng',
        'total': total
    })

# Trang thanh toán
@app.route('/checkout', methods=['GET', 'POST'])
def checkout():
    # Kiểm tra xem có phải là mua ngay không
    buy_now = request.args.get('buy_now', type=int, default=0)
    
    if buy_now and 'temp_cart' in session:
        cart = session.get('temp_cart', [])
    else:
        cart = session.get('cart', [])
    
    if not cart:
        flash('Giỏ hàng của bạn đang trống', 'error')
        return redirect(url_for('view_cart'))
    
    if request.method == 'POST':
        # Kiểm tra đăng nhập
        if 'user_id' not in session:
            flash('Vui lòng đăng nhập để tiếp tục thanh toán', 'error')
            return redirect(url_for('login', next=url_for('checkout')))
        
        # Lấy thông tin từ form
        shipping_address = request.form.get('shipping_address')
        payment_method = request.form.get('payment_method', 'cod')
        
        if not shipping_address:
            flash('Vui lòng điền địa chỉ giao hàng', 'error')
            return redirect(url_for('checkout'))
        
        # Tạo đơn hàng mới
        total_amount = sum(item['price'] * item['quantity'] for item in cart)
        
        order = Order(
            user_id=session['user_id'],
            total_amount=total_amount,
            status='pending',
            shipping_address=shipping_address
        )
        db.session.add(order)
        db.session.flush()  # Để lấy order.id
        
        # Thêm chi tiết đơn hàng
        for item in cart:
            detail = OrderDetail(
                order_id=order.id,
                product_variant_id=item['variant_id'],
                quantity=item['quantity'],
                unit_price=item['price'],
                total_price=item['price'] * item['quantity']
            )
            db.session.add(detail)
            
            # Cập nhật số lượng tồn kho
            variant = ProductVariant.query.get(item['variant_id'])
            if variant:
                variant.stock_quantity -= item['quantity']
        
        db.session.commit()
        
        # Xóa giỏ hàng sau khi đặt hàng thành công
        if buy_now and 'temp_cart' in session:
            session.pop('temp_cart', None)
        else:
            session.pop('cart', None)
        
        flash('Đặt hàng thành công! Cảm ơn bạn đã mua sắm.', 'success')
        return redirect(url_for('order_confirmation', order_id=order.id))
    
    # Tính tổng tiền
    total = sum(item['price'] * item['quantity'] for item in cart)
    
    # Nếu đã đăng nhập, lấy thông tin địa chỉ của khách hàng
    address = ''
    if 'user_id' in session:
        user = User.query.get(session['user_id'])
        if user and user.address:
            address = user.address
    
    return render_template('checkout.html', cart=cart, total=total, address=address)

# Trang xác nhận đơn hàng
@app.route('/order_confirmation/<int:order_id>')
def order_confirmation(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    order = Order.query.get_or_404(order_id)
    
    if order.user_id != session['user_id']:
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền xem', 'error')
        return redirect(url_for('home'))
    
    return render_template('order_confirmation.html', order=order)

# Trang đăng nhập
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        
        if not email or not password:
            flash('Vui lòng nhập email và mật khẩu', 'error')
            return redirect(url_for('login'))
        
        user = User.query.filter_by(email=email).first()
        
        if not user or not check_password_hash(user.password_hash, password):
            flash('Email hoặc mật khẩu không đúng', 'error')
            return redirect(url_for('login'))
        
        # Lưu thông tin đăng nhập vào session
        session['user_id'] = user.id
        session['user_name'] = user.full_name
        session['dark_mode'] = user.dark_mode
        session['is_admin'] = user.is_admin
        
        # Chuyển hướng đến trang tiếp theo (nếu có)
        next_page = request.args.get('next')
        if next_page:
            return redirect(next_page)
        
        flash('Đăng nhập thành công!', 'success')
        return redirect(url_for('home'))
    
    return render_template('login.html')

# Trang đăng ký
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        full_name = request.form.get('full_name')
        email = request.form.get('email')
        password = request.form.get('password')
        phone = request.form.get('phone')
        address = request.form.get('address')
        
        if not full_name or not email or not password:
            flash('Vui lòng điền đầy đủ thông tin bắt buộc', 'error')
            return redirect(url_for('register'))
        
        # Kiểm tra email đã tồn tại
        if User.query.filter_by(email=email).first():
            flash('Email đã được sử dụng, vui lòng chọn email khác', 'error')
            return redirect(url_for('register'))
        
        # Mã hóa mật khẩu
        hashed_password = generate_password_hash(password)
        
        # Tạo người dùng mới
        user = User(
            username=email.split('@')[0],  # Sử dụng phần trước @ làm username
            email=email,
            password_hash=hashed_password,
            full_name=full_name,
            phone=phone,
            address=address
        )
        
        try:
            db.session.add(user)
            db.session.commit()
            
            # Đăng nhập tự động sau khi đăng ký
            session['user_id'] = user.id
            session['user_name'] = user.full_name
            session['dark_mode'] = user.dark_mode
            session['is_admin'] = user.is_admin
            
            flash('Đăng ký thành công!', 'success')
            return redirect(url_for('home'))
            
        except Exception as e:
            db.session.rollback()
            flash('Đã xảy ra lỗi, vui lòng thử lại', 'error')
            return redirect(url_for('register'))
    
    return render_template('register.html')

# Đăng xuất
@app.route('/logout')
def logout():
    session.clear()
    flash('Đã đăng xuất thành công', 'success')
    return redirect(url_for('home'))

# Trang tài khoản của tôi
@app.route('/my_account')
def my_account():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user = User.query.get(session['user_id'])
    orders = Order.query.filter_by(user_id=session['user_id']).order_by(Order.created_at.desc()).all()
    
    return render_template('my_account.html', customer=user, orders=orders)

# Cập nhật thông tin cá nhân
@app.route('/update_profile', methods=['POST'])
def update_profile():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    full_name = request.form.get('full_name')
    phone = request.form.get('phone')
    
    if not full_name:
        flash('Vui lòng nhập họ và tên', 'error')
        return redirect(url_for('my_account'))
    
    user = User.query.get(session['user_id'])
    user.full_name = full_name
    user.phone = phone
    user.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        session['user_name'] = full_name
        flash('Cập nhật thông tin thành công!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    return redirect(url_for('my_account', _anchor='profile', profile_updated=True))

# Cập nhật địa chỉ
@app.route('/update_address', methods=['POST'])
def update_address():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    address = request.form.get('address')
    
    if not address:
        flash('Vui lòng nhập địa chỉ', 'error')
        return redirect(url_for('my_account'))
    
    user = User.query.get(session['user_id'])
    user.address = address
    user.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        flash('Cập nhật địa chỉ thành công!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    return redirect(url_for('my_account', _anchor='address', address_updated=True))

# Đổi mật khẩu
@app.route('/change_password', methods=['POST'])
def change_password():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    current_password = request.form.get('current_password')
    new_password = request.form.get('new_password')
    confirm_password = request.form.get('confirm_password')
    
    if not current_password or not new_password or not confirm_password:
        flash('Vui lòng điền đầy đủ thông tin', 'error')
        return redirect(url_for('my_account', _anchor='password'))
    
    if new_password != confirm_password:
        flash('Mật khẩu xác nhận không khớp với mật khẩu mới', 'error')
        return redirect(url_for('my_account', _anchor='password', password_error='Mật khẩu xác nhận không khớp với mật khẩu mới'))
    
    # Kiểm tra độ mạnh mật khẩu
    if len(new_password) < 6:
        flash('Mật khẩu phải có ít nhất 6 ký tự', 'error')
        return redirect(url_for('my_account', _anchor='password', password_error='Mật khẩu phải có ít nhất 6 ký tự'))
    
    user = User.query.get(session['user_id'])
    
    if not check_password_hash(user.password_hash, current_password):
        flash('Mật khẩu hiện tại không đúng', 'error')
        return redirect(url_for('my_account', _anchor='password', password_error='Mật khẩu hiện tại không đúng'))
    
    # Cập nhật mật khẩu mới
    user.password_hash = generate_password_hash(new_password)
    user.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        flash('Đổi mật khẩu thành công!', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    return redirect(url_for('my_account', _anchor='password', password_updated=True))

# Chi tiết đơn hàng
@app.route('/order_detail/<int:order_id>')
def order_detail(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    order = Order.query.get_or_404(order_id)
    
    if order.user_id != session['user_id']:
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền xem', 'error')
        return redirect(url_for('my_account'))
    
    return render_template('order_detail.html', order=order)

# Hủy đơn hàng
@app.route('/cancel_order/<int:order_id>', methods=['POST'])
def cancel_order(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    order = Order.query.get_or_404(order_id)
    
    if order.user_id != session['user_id']:
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền hủy', 'error')
        return redirect(url_for('my_account'))
    
    if order.status not in ['pending', 'processing']:
        flash('Không thể hủy đơn hàng ở trạng thái này', 'error')
        return redirect(url_for('order_detail', order_id=order_id))
    
    try:
        order.status = 'cancelled'
        order.updated_at = datetime.utcnow()
        
        # Hoàn lại số lượng tồn kho
        for detail in order.details:
            variant = detail.variant
            if variant:
                variant.stock_quantity += detail.quantity
        
        db.session.commit()
        flash('Đã hủy đơn hàng thành công', 'success')
    except Exception as e:
        db.session.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    return redirect(url_for('order_detail', order_id=order_id))

# Trang liên hệ
@app.route('/contact', methods=['GET', 'POST'])
def contact():
    if request.method == 'POST':
        name = request.form.get('name')
        email = request.form.get('email')
        subject = request.form.get('subject')
        message = request.form.get('message')
        
        if not name or not email or not message:
            flash('Vui lòng điền đầy đủ thông tin bắt buộc', 'error')
            return redirect(url_for('contact'))
        
        contact_message = ContactMessage(
            name=name,
            email=email,
            subject=subject,
            message=message
        )
        
        try:
            db.session.add(contact_message)
            db.session.commit()
            flash('Cảm ơn bạn đã liên hệ! Chúng tôi sẽ phản hồi sớm nhất có thể.', 'success')
        except Exception as e:
            db.session.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
        
        return redirect(url_for('contact'))
    
    return render_template('contact.html')

# Đăng ký nhận tin
@app.route('/subscribe_newsletter', methods=['POST'])
def subscribe_newsletter():
    email = request.form.get('email')
    
    if not email:
        return jsonify({'success': False, 'message': 'Vui lòng nhập email'})
    
    # Kiểm tra email đã đăng ký chưa
    existing = NewsletterSubscription.query.filter_by(email=email).first()
    
    if existing:
        if existing.is_active:
            return jsonify({'success': False, 'message': 'Email này đã đăng ký nhận tin'})
        else:
            existing.is_active = True
            existing.created_at = datetime.utcnow()
    else:
        subscription = NewsletterSubscription(email=email)
        db.session.add(subscription)
    
    try:
        db.session.commit()
        return jsonify({'success': True, 'message': 'Đăng ký nhận tin thành công!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Thêm/xóa sản phẩm yêu thích
@app.route('/toggle_wishlist', methods=['POST'])
def toggle_wishlist():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    product_id = request.form.get('product_id', type=int)
    
    if not product_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    # Kiểm tra xem sản phẩm đã có trong wishlist chưa
    existing = Wishlist.query.filter_by(user_id=session['user_id'], product_id=product_id).first()
    
    try:
        if existing:
            # Xóa khỏi wishlist
            db.session.delete(existing)
            message = 'Đã xóa khỏi danh sách yêu thích'
            is_in_wishlist = False
        else:
            # Thêm vào wishlist
            wishlist_item = Wishlist(user_id=session['user_id'], product_id=product_id)
            db.session.add(wishlist_item)
            message = 'Đã thêm vào danh sách yêu thích'
            is_in_wishlist = True
        
        db.session.commit()
        return jsonify({
            'success': True, 
            'message': message,
            'is_in_wishlist': is_in_wishlist
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Trang danh sách yêu thích
@app.route('/wishlist')
def wishlist():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    wishlist_items = db.session.query(Wishlist, Product, Category).join(
        Product, Wishlist.product_id == Product.id
    ).join(
        Category, Product.category_id == Category.id
    ).filter(
        Wishlist.user_id == session['user_id']
    ).order_by(Wishlist.created_at.desc()).all()
    
    return render_template('wishlist.html', wishlist_items=wishlist_items)

# Thêm đánh giá sản phẩm
@app.route('/add_review', methods=['POST'])
def add_review():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    product_id = request.form.get('product_id', type=int)
    rating = request.form.get('rating', type=int)
    comment = request.form.get('comment', '')
    
    if not product_id or not rating or rating < 1 or rating > 5:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    # Kiểm tra xem đã đánh giá chưa
    existing_review = ProductReview.query.filter_by(
        user_id=session['user_id'], 
        product_id=product_id
    ).first()
    
    try:
        if existing_review:
            # Cập nhật đánh giá cũ
            existing_review.rating = rating
            existing_review.comment = comment
            existing_review.created_at = datetime.utcnow()
        else:
            # Tạo đánh giá mới
            review = ProductReview(
                user_id=session['user_id'],
                product_id=product_id,
                rating=rating,
                comment=comment
            )
            db.session.add(review)
        
        db.session.commit()
        return jsonify({'success': True, 'message': 'Đánh giá đã được gửi thành công!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Thêm bình luận sản phẩm
@app.route('/add_comment', methods=['POST'])
def add_comment():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    product_id = request.form.get('product_id', type=int)
    content = request.form.get('content', '').strip()
    
    if not product_id or not content:
        return jsonify({'success': False, 'message': 'Vui lòng nhập nội dung bình luận'})
    
    comment = ProductComment(
        user_id=session['user_id'],
        product_id=product_id,
        comment=content,
        is_approved=True  # Tự động duyệt cho đơn giản
    )
    
    try:
        db.session.add(comment)
        db.session.commit()
        return jsonify({'success': True, 'message': 'Bình luận đã được gửi thành công!'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Lấy bình luận sản phẩm
@app.route('/get_comments/<int:product_id>')
def get_comments(product_id):
    comments = db.session.query(ProductComment, User).join(
        User, ProductComment.user_id == User.id
    ).filter(
        ProductComment.product_id == product_id,
        ProductComment.is_approved == True
    ).order_by(ProductComment.created_at.desc()).all()
    
    result = []
    for comment, user in comments:
        result.append({
            'id': comment.id,
            'content': comment.comment,
            'created_at': comment.created_at.strftime('%d/%m/%Y %H:%M'),
            'customer_name': user.full_name,
            'admin_reply': comment.admin_reply,
            'reply_date': comment.reply_date.strftime('%d/%m/%Y %H:%M') if comment.reply_date else None
        })
    
    return jsonify(result)

# Lấy đánh giá sản phẩm
@app.route('/get_reviews/<int:product_id>')
def get_reviews(product_id):
    reviews = db.session.query(ProductReview, User).join(
        User, ProductReview.user_id == User.id
    ).filter(
        ProductReview.product_id == product_id
    ).order_by(ProductReview.created_at.desc()).all()
    
    # Tính điểm trung bình
    avg_rating = db.session.query(db.func.avg(ProductReview.rating)).filter_by(product_id=product_id).scalar()
    total_reviews = len(reviews)
    
    result_reviews = []
    for review, user in reviews:
        result_reviews.append({
            'id': review.id,
            'rating': review.rating,
            'comment': review.comment,
            'created_at': review.created_at.strftime('%d/%m/%Y %H:%M'),
            'customer_name': user.full_name
        })
    
    return jsonify({
        'reviews': result_reviews,
        'avg_rating': float(avg_rating) if avg_rating else 0,
        'total_reviews': total_reviews
    })

# Bật/tắt chế độ tối
@app.route('/toggle_dark_mode', methods=['POST'])
def toggle_dark_mode():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    # Đảo ngược trạng thái dark mode
    current_mode = session.get('dark_mode', False)
    new_mode = not current_mode
    
    user = User.query.get(session['user_id'])
    user.dark_mode = new_mode
    user.updated_at = datetime.utcnow()
    
    try:
        db.session.commit()
        session['dark_mode'] = new_mode
        
        return jsonify({
            'success': True, 
            'dark_mode': new_mode,
            'message': f'Đã {"bật" if new_mode else "tắt"} chế độ tối'
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# ===== ADMIN ROUTES =====

# Kiểm tra quyền admin
def admin_required(f):
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Vui lòng đăng nhập', 'error')
            return redirect(url_for('login'))
        
        if not session.get('is_admin', False):
            flash('Bạn không có quyền truy cập trang này', 'error')
            return redirect(url_for('home'))
        
        return f(*args, **kwargs)
    
    decorated_function.__name__ = f.__name__
    return decorated_function

# Trang quản trị chính
@app.route('/admin')
@admin_required
def admin_dashboard():
    total_products = Product.query.count()
    total_orders = Order.query.count()
    total_customers = User.query.filter_by(is_admin=False).count()
    total_revenue = db.session.query(db.func.sum(Order.total_amount)).filter(
        Order.status.in_(['completed', 'shipped'])
    ).scalar() or 0
    
    # Đơn hàng gần đây
    recent_orders = db.session.query(Order, User).join(
        User, Order.user_id == User.id
    ).order_by(Order.created_at.desc()).limit(10).all()
    
    # Sản phẩm bán chạy (giả lập)
    best_selling = Product.query.limit(5).all()
    
    return render_template('admin/dashboard.html',
                          total_products=total_products,
                          total_orders=total_orders,
                          total_customers=total_customers,
                          total_revenue=float(total_revenue),
                          recent_orders=recent_orders,
                          best_selling=best_selling)

# Quản lý sản phẩm
@app.route('/admin/products')
@admin_required
def admin_products():
    products = db.session.query(Product, Category).join(
        Category, Product.category_id == Category.id
    ).order_by(Product.created_at.desc()).all()
    
    return render_template('admin/products.html', products=products)

# Chỉnh sửa sản phẩm
@app.route('/admin/edit_product/<int:product_id>', methods=['GET', 'POST'])
@admin_required
def admin_edit_product(product_id):
    product = Product.query.get_or_404(product_id)
    
    if request.method == 'POST':
        product_name = request.form.get('product_name')
        description = request.form.get('description')
        price = request.form.get('price', type=float)
        category_id = request.form.get('category_id', type=int)
        
        try:
            product.name = product_name
            product.description = description
            product.base_price = price
            product.category_id = category_id
            product.updated_at = datetime.utcnow()
            
            db.session.commit()
            flash('Cập nhật sản phẩm thành công!', 'success')
            return redirect(url_for('admin_products'))
        except Exception as e:
            db.session.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    categories = Category.query.all()
    return render_template('admin/edit_product.html', product=product, categories=categories)

# Quản lý đơn hàng
@app.route('/admin/orders')
@admin_required
def admin_orders():
    status_filter = request.args.get('status', '')
    
    query = db.session.query(Order, User).join(User, Order.user_id == User.id)
    
    if status_filter:
        query = query.filter(Order.status == status_filter)
    
    orders = query.order_by(Order.created_at.desc()).all()
    
    return render_template('admin/orders.html', orders=orders, status_filter=status_filter)

# Cập nhật trạng thái đơn hàng
@app.route('/admin/update_order_status', methods=['POST'])
@admin_required
def admin_update_order_status():
    order_id = request.form.get('order_id', type=int)
    new_status = request.form.get('status')
    
    if not order_id or not new_status:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    order = Order.query.get(order_id)
    if not order:
        return jsonify({'success': False, 'message': 'Đơn hàng không tồn tại'})
    
    try:
        order.status = new_status
        order.updated_at = datetime.utcnow()
        db.session.commit()
        return jsonify({'success': True, 'message': 'Cập nhật trạng thái thành công'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Báo cáo doanh thu
@app.route('/admin/reports')
@admin_required
def admin_reports():
    # Doanh thu theo tháng (12 tháng gần đây)
    monthly_revenue = []
    for i in range(12):
        month_start = datetime.now().replace(day=1) - timedelta(days=30*i)
        month_end = (month_start + timedelta(days=32)).replace(day=1) - timedelta(days=1)
        
        revenue = db.session.query(db.func.sum(Order.total_amount)).filter(
            Order.status.in_(['completed', 'shipped']),
            Order.created_at >= month_start,
            Order.created_at <= month_end
        ).scalar() or 0
        
        monthly_revenue.append({
            'month': month_start.strftime('%Y-%m'),
            'revenue': float(revenue)
        })
    
    # Doanh thu theo danh mục
    category_revenue = db.session.query(
        Category.name,
        db.func.sum(OrderDetail.total_price).label('revenue')
    ).join(
        Product, Category.id == Product.category_id
    ).join(
        ProductVariant, Product.id == ProductVariant.product_id
    ).join(
        OrderDetail, ProductVariant.id == OrderDetail.product_variant_id
    ).join(
        Order, OrderDetail.order_id == Order.id
    ).filter(
        Order.status.in_(['completed', 'shipped'])
    ).group_by(Category.name).all()
    
    # Doanh thu 7 ngày gần đây
    daily_revenue = []
    for i in range(7):
        day = datetime.now().date() - timedelta(days=i)
        revenue = db.session.query(db.func.sum(Order.total_amount)).filter(
            Order.status.in_(['completed', 'shipped']),
            db.func.date(Order.created_at) == day
        ).scalar() or 0
        
        daily_revenue.append({
            'date': day.strftime('%Y-%m-%d'),
            'revenue': float(revenue)
        })
    
    return render_template('admin/reports.html',
                          monthly_revenue=monthly_revenue,
                          category_revenue=category_revenue,
                          daily_revenue=daily_revenue)

# Quản lý tin nhắn liên hệ
@app.route('/admin/contact_messages')
@admin_required
def admin_contact_messages():
    messages = ContactMessage.query.order_by(ContactMessage.created_at.desc()).all()
    return render_template('admin/contact_messages.html', messages=messages)

# Cập nhật trạng thái tin nhắn liên hệ
@app.route('/admin/update_message_status', methods=['POST'])
@admin_required
def admin_update_message_status():
    message_id = request.form.get('message_id', type=int)
    new_status = request.form.get('status') == 'true'
    
    if not message_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    message = ContactMessage.query.get(message_id)
    if not message:
        return jsonify({'success': False, 'message': 'Tin nhắn không tồn tại'})
    
    try:
        message.is_read = new_status
        db.session.commit()
        return jsonify({'success': True, 'message': 'Cập nhật trạng thái thành công'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Quản lý bình luận
@app.route('/admin/comments')
@admin_required
def admin_comments():
    comments = db.session.query(ProductComment, User, Product).join(
        User, ProductComment.user_id == User.id
    ).join(
        Product, ProductComment.product_id == Product.id
    ).order_by(ProductComment.created_at.desc()).all()
    
    return render_template('admin/comments.html', comments=comments)

# Trả lời bình luận
@app.route('/admin/reply_comment', methods=['POST'])
@admin_required
def admin_reply_comment():
    comment_id = request.form.get('comment_id', type=int)
    reply = request.form.get('reply', '').strip()
    
    if not comment_id or not reply:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    comment = ProductComment.query.get(comment_id)
    if not comment:
        return jsonify({'success': False, 'message': 'Bình luận không tồn tại'})
    
    try:
        comment.admin_reply = reply
        comment.reply_date = datetime.utcnow()
        db.session.commit()
        return jsonify({'success': True, 'message': 'Trả lời bình luận thành công'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Ẩn/hiện bình luận
@app.route('/admin/toggle_comment_visibility', methods=['POST'])
@admin_required
def admin_toggle_comment_visibility():
    comment_id = request.form.get('comment_id', type=int)
    
    if not comment_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    comment = ProductComment.query.get(comment_id)
    if not comment:
        return jsonify({'success': False, 'message': 'Bình luận không tồn tại'})
    
    try:
        comment.is_approved = not comment.is_approved
        db.session.commit()
        
        action = 'hiện' if comment.is_approved else 'ẩn'
        return jsonify({'success': True, 'message': f'Đã {action} bình luận'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})

# Context processor để truyền thông tin user và giỏ hàng cho tất cả template
@app.context_processor
def inject_user_and_cart():
    cart_count = 0
    if 'cart' in session:
        cart_count = sum(item['quantity'] for item in session['cart'])
    
    return {
        'user_id': session.get('user_id'),
        'user_name': session.get('user_name'),
        'dark_mode': session.get('dark_mode', False),
        'is_admin': session.get('is_admin', False),
        'cart_count': cart_count
    }

# Xử lý lỗi 404
@app.errorhandler(404)
def not_found_error(error):
    return render_template('404.html'), 404

# Xử lý lỗi 500
@app.errorhandler(500)
def internal_error(error):
    db.session.rollback()
    return render_template('500.html'), 500

# Khởi tạo database khi import module
def create_app():
    init_db()
    return app

# Khởi tạo database ngay khi module được import
try:
    with app.app_context():
        db.create_all()
        
        # Kiểm tra xem đã có dữ liệu chưa
        if User.query.first() is None:
            # Thêm màu sắc
            colors = [
                Color(name='Đen', hex_code='#000000'),
                Color(name='Trắng', hex_code='#FFFFFF'),
                Color(name='Xanh dương', hex_code='#0000FF'),
                Color(name='Đỏ', hex_code='#FF0000'),
                Color(name='Xanh lá', hex_code='#008000'),
                Color(name='Vàng', hex_code='#FFFF00'),
                Color(name='Hồng', hex_code='#FFC0CB'),
                Color(name='Nâu', hex_code='#A52A2A'),
                Color(name='Xám', hex_code='#808080')
            ]
            for color in colors:
                db.session.add(color)
            
            # Thêm kích thước
            sizes = [
                Size(name='XS', description='Extra Small'),
                Size(name='S', description='Small'),
                Size(name='M', description='Medium'),
                Size(name='L', description='Large'),
                Size(name='XL', description='Extra Large'),
                Size(name='XXL', description='Double Extra Large'),
                Size(name='28', description='Eo 28 inch'),
                Size(name='29', description='Eo 29 inch'),
                Size(name='30', description='Eo 30 inch'),
                Size(name='31', description='Eo 31 inch'),
                Size(name='32', description='Eo 32 inch'),
                Size(name='33', description='Eo 33 inch')
            ]
            for size in sizes:
                db.session.add(size)
            
            # Thêm danh mục
            categories = [
                Category(name='Áo Nam', description='Các loại áo dành cho nam giới', image_url='/static/images/ao-nam.jpg'),
                Category(name='Áo Nữ', description='Các loại áo dành cho nữ giới', image_url='/static/images/ao-nu.jpg'),
                Category(name='Quần Nam', description='Các loại quần dành cho nam giới', image_url='/static/images/quan-nam.jpg'),
                Category(name='Quần Nữ', description='Các loại quần dành cho nữ giới', image_url='/static/images/quan-nu.jpg'),
                Category(name='Váy Đầm', description='Các loại váy đầm nữ', image_url='/static/images/vay-dam.jpg'),
                Category(name='Phụ Kiện', description='Các loại phụ kiện thời trang', image_url='/static/images/phu-kien.jpg')
            ]
            for category in categories:
                db.session.add(category)
            
            db.session.commit()
            
            # Thêm sản phẩm
            products = [
                Product(name='Áo Thun Nam Đen', description='Áo thun nam màu đen, chất liệu cotton thoáng mát', base_price=299000, category_id=1, image_url='/static/images/ao-thun-nam-den.jpg'),
                Product(name='Áo Sơ Mi Nam Trắng', description='Áo sơ mi nam màu trắng, phù hợp đi làm', base_price=499000, category_id=1, image_url='/static/images/ao-so-mi-nam-trang.jpg'),
                Product(name='Áo Thun Nữ Hồng', description='Áo thun nữ màu hồng, thiết kế trẻ trung', base_price=259000, category_id=2, image_url='/static/images/ao-thun-nu-hong.jpg'),
                Product(name='Áo Sơ Mi Nữ Trắng', description='Áo sơ mi nữ màu trắng, thanh lịch', base_price=459000, category_id=2, image_url='/static/images/ao-so-mi-nu-trang.jpg'),
                Product(name='Áo Khoác Nữ Nhẹ', description='Áo khoác nữ nhẹ, phù hợp mùa thu', base_price=699000, category_id=2, image_url='/static/images/ao-khoac-nu-nhe.jpg'),
                Product(name='Quần Jean Nam Xanh', description='Quần jean nam màu xanh, form slim fit', base_price=599000, category_id=3, image_url='/static/images/quan-jean-nam-xanh.jpg'),
                Product(name='Quần Kaki Nam Nâu', description='Quần kaki nam màu nâu, phong cách lịch lãm', base_price=549000, category_id=3, image_url='/static/images/quan-kaki-nam-nau.jpg'),
                Product(name='Quần Jean Nữ Xanh Nhạt', description='Quần jean nữ màu xanh nhạt, form skinny', base_price=559000, category_id=4, image_url='/static/images/quan-jean-nu-xanh-nhat.jpg'),
                Product(name='Váy Đầm Suông Đen', description='Váy đầm suông màu đen, thanh lịch', base_price=799000, category_id=5, image_url='/static/images/vay-dam-suong-den.jpg')
            ]
            for product in products:
                db.session.add(product)
            
            db.session.commit()
            
            # Thêm biến thể sản phẩm
            variants = [
                # Áo Thun Nam Đen
                ProductVariant(product_id=1, color_id=1, size_id=2, price=299000, stock_quantity=50, sku='ATN-DEN-S'),
                ProductVariant(product_id=1, color_id=1, size_id=3, price=299000, stock_quantity=45, sku='ATN-DEN-M'),
                ProductVariant(product_id=1, color_id=1, size_id=4, price=299000, stock_quantity=40, sku='ATN-DEN-L'),
                ProductVariant(product_id=1, color_id=1, size_id=5, price=299000, stock_quantity=35, sku='ATN-DEN-XL'),
                # Áo Sơ Mi Nam Trắng
                ProductVariant(product_id=2, color_id=2, size_id=2, price=499000, stock_quantity=30, sku='ASM-TRA-S'),
                ProductVariant(product_id=2, color_id=2, size_id=3, price=499000, stock_quantity=25, sku='ASM-TRA-M'),
                ProductVariant(product_id=2, color_id=2, size_id=4, price=499000, stock_quantity=20, sku='ASM-TRA-L'),
                ProductVariant(product_id=2, color_id=2, size_id=5, price=499000, stock_quantity=15, sku='ASM-TRA-XL'),
                # Áo Thun Nữ Hồng
                ProductVariant(product_id=3, color_id=7, size_id=1, price=259000, stock_quantity=40, sku='ATN-HON-XS'),
                ProductVariant(product_id=3, color_id=7, size_id=2, price=259000, stock_quantity=35, sku='ATN-HON-S'),
                ProductVariant(product_id=3, color_id=7, size_id=3, price=259000, stock_quantity=30, sku='ATN-HON-M'),
                ProductVariant(product_id=3, color_id=7, size_id=4, price=259000, stock_quantity=25, sku='ATN-HON-L'),
                # Áo Sơ Mi Nữ Trắng
                ProductVariant(product_id=4, color_id=2, size_id=1, price=459000, stock_quantity=25, sku='ASN-TRA-XS'),
                ProductVariant(product_id=4, color_id=2, size_id=2, price=459000, stock_quantity=20, sku='ASN-TRA-S'),
                ProductVariant(product_id=4, color_id=2, size_id=3, price=459000, stock_quantity=18, sku='ASN-TRA-M'),
                ProductVariant(product_id=4, color_id=2, size_id=4, price=459000, stock_quantity=15, sku='ASN-TRA-L'),
                # Áo Khoác Nữ Nhẹ
                ProductVariant(product_id=5, color_id=1, size_id=2, price=699000, stock_quantity=20, sku='AKN-DEN-S'),
                ProductVariant(product_id=5, color_id=1, size_id=3, price=699000, stock_quantity=18, sku='AKN-DEN-M'),
                ProductVariant(product_id=5, color_id=1, size_id=4, price=699000, stock_quantity=15, sku='AKN-DEN-L'),
                ProductVariant(product_id=5, color_id=9, size_id=2, price=699000, stock_quantity=12, sku='AKN-XAM-S'),
                ProductVariant(product_id=5, color_id=9, size_id=3, price=699000, stock_quantity=10, sku='AKN-XAM-M'),
                # Quần Jean Nam Xanh
                ProductVariant(product_id=6, color_id=3, size_id=7, price=599000, stock_quantity=25, sku='QJN-XAN-28'),
                ProductVariant(product_id=6, color_id=3, size_id=8, price=599000, stock_quantity=22, sku='QJN-XAN-29'),
                ProductVariant(product_id=6, color_id=3, size_id=9, price=599000, stock_quantity=20, sku='QJN-XAN-30'),
                ProductVariant(product_id=6, color_id=3, size_id=10, price=599000, stock_quantity=18, sku='QJN-XAN-31'),
                ProductVariant(product_id=6, color_id=3, size_id=11, price=599000, stock_quantity=15, sku='QJN-XAN-32'),
                # Quần Kaki Nam Nâu
                ProductVariant(product_id=7, color_id=8, size_id=7, price=549000, stock_quantity=20, sku='QKN-NAU-28'),
                ProductVariant(product_id=7, color_id=8, size_id=8, price=549000, stock_quantity=18, sku='QKN-NAU-29'),
                ProductVariant(product_id=7, color_id=8, size_id=9, price=549000, stock_quantity=16, sku='QKN-NAU-30'),
                ProductVariant(product_id=7, color_id=8, size_id=10, price=549000, stock_quantity=14, sku='QKN-NAU-31'),
                ProductVariant(product_id=7, color_id=8, size_id=11, price=549000, stock_quantity=12, sku='QKN-NAU-32'),
                # Quần Jean Nữ Xanh Nhạt
                ProductVariant(product_id=8, color_id=3, size_id=1, price=559000, stock_quantity=18, sku='QJN-XAN-XS'),
                ProductVariant(product_id=8, color_id=3, size_id=2, price=559000, stock_quantity=16, sku='QJN-XAN-S'),
                ProductVariant(product_id=8, color_id=3, size_id=3, price=559000, stock_quantity=14, sku='QJN-XAN-M'),
                ProductVariant(product_id=8, color_id=3, size_id=4, price=559000, stock_quantity=12, sku='QJN-XAN-L'),
                # Váy Đầm Suông Đen
                ProductVariant(product_id=9, color_id=1, size_id=1, price=799000, stock_quantity=15, sku='VDS-DEN-XS'),
                ProductVariant(product_id=9, color_id=1, size_id=2, price=799000, stock_quantity=12, sku='VDS-DEN-S'),
                ProductVariant(product_id=9, color_id=1, size_id=3, price=799000, stock_quantity=10, sku='VDS-DEN-M'),
                ProductVariant(product_id=9, color_id=1, size_id=4, price=799000, stock_quantity=8, sku='VDS-DEN-L')
            ]
            for variant in variants:
                db.session.add(variant)
            
            # Thêm người dùng mẫu
            users = [
                User(username='admin', email='admin@fashionstore.com', password_hash=generate_password_hash('admin123'), full_name='Quản trị viên', phone='0123456789', address='Hà Nội', is_admin=True),
                User(username='user1', email='user1@email.com', password_hash=generate_password_hash('password123'), full_name='Nguyễn Văn A', phone='0987654321', address='TP.HCM'),
                User(username='user2', email='user2@email.com', password_hash=generate_password_hash('password123'), full_name='Trần Thị B', phone='0912345678', address='Đà Nẵng'),
                User(username='user3', email='user3@email.com', password_hash=generate_password_hash('password123'), full_name='Lê Văn C', phone='0934567890', address='Hải Phòng'),
                User(username='user4', email='user4@email.com', password_hash=generate_password_hash('password123'), full_name='Phạm Thị D', phone='0945678901', address='Cần Thơ')
            ]
            for user in users:
                db.session.add(user)
            
            db.session.commit()
            
            # Thêm đơn hàng mẫu
            orders = [
                Order(user_id=2, total_amount=598000, status='completed', shipping_address='TP.HCM', phone='0987654321'),
                Order(user_id=3, total_amount=1158000, status='processing', shipping_address='Đà Nẵng', phone='0912345678'),
                Order(user_id=4, total_amount=799000, status='pending', shipping_address='Hải Phòng', phone='0934567890'),
                Order(user_id=5, total_amount=1098000, status='completed', shipping_address='Cần Thơ', phone='0945678901')
            ]
            for order in orders:
                db.session.add(order)
            
            db.session.commit()
            
            # Thêm chi tiết đơn hàng
            order_details = [
                OrderDetail(order_id=1, product_variant_id=1, quantity=2, unit_price=299000, total_price=598000),
                OrderDetail(order_id=2, product_variant_id=13, quantity=1, unit_price=459000, total_price=459000),
                OrderDetail(order_id=2, product_variant_id=17, quantity=1, unit_price=699000, total_price=699000),
                OrderDetail(order_id=3, product_variant_id=33, quantity=1, unit_price=799000, total_price=799000),
                OrderDetail(order_id=4, product_variant_id=6, quantity=1, unit_price=499000, total_price=499000),
                OrderDetail(order_id=4, product_variant_id=21, quantity=1, unit_price=599000, total_price=599000)
            ]
            for detail in order_details:
                db.session.add(detail)
            
            # Thêm đánh giá sản phẩm
            reviews = [
                ProductReview(product_id=1, user_id=2, rating=5, comment='Áo rất đẹp và chất lượng tốt'),
                ProductReview(product_id=2, user_id=3, rating=4, comment='Áo sơ mi đẹp, phù hợp đi làm'),
                ProductReview(product_id=3, user_id=4, rating=5, comment='Màu hồng rất xinh, chất liệu mềm mại'),
                ProductReview(product_id=9, user_id=5, rating=4, comment='Váy đẹp nhưng hơi dài')
            ]
            for review in reviews:
                db.session.add(review)
            
            # Thêm wishlist
            wishlists = [
                Wishlist(user_id=2, product_id=3),
                Wishlist(user_id=2, product_id=5),
                Wishlist(user_id=2, product_id=9),
                Wishlist(user_id=3, product_id=1),
                Wishlist(user_id=3, product_id=6),
                Wishlist(user_id=4, product_id=2),
                Wishlist(user_id=4, product_id=4),
                Wishlist(user_id=4, product_id=8),
                Wishlist(user_id=5, product_id=7),
                Wishlist(user_id=5, product_id=9)
            ]
            for wishlist in wishlists:
                db.session.add(wishlist)
            
            # Thêm bình luận sản phẩm
            comments = [
                ProductComment(product_id=1, user_id=2, comment='Áo này có màu nào khác không?', is_approved=True),
                ProductComment(product_id=2, user_id=3, comment='Size M có vừa với người cao 1m7 không?', is_approved=True),
                ProductComment(product_id=3, user_id=4, comment='Chất liệu có co giãn không?', is_approved=False),
                ProductComment(product_id=9, user_id=5, comment='Váy này có thể giặt máy được không?', is_approved=True)
            ]
            for comment in comments:
                db.session.add(comment)
            
            # Thêm tin nhắn liên hệ
            messages = [
                ContactMessage(name='Nguyễn Văn E', email='user5@email.com', subject='Hỏi về sản phẩm', message='Tôi muốn hỏi về chính sách đổi trả'),
                ContactMessage(name='Trần Thị F', email='user6@email.com', subject='Khiếu nại', message='Sản phẩm tôi nhận không đúng màu'),
                ContactMessage(name='Lê Văn G', email='user7@email.com', subject='Góp ý', message='Website rất đẹp và dễ sử dụng')
            ]
            for message in messages:
                db.session.add(message)
            
            # Thêm đăng ký newsletter
            newsletters = [
                NewsletterSubscription(email='newsletter1@email.com'),
                NewsletterSubscription(email='newsletter2@email.com'),
                NewsletterSubscription(email='newsletter3@email.com'),
                NewsletterSubscription(email='newsletter4@email.com'),
                NewsletterSubscription(email='newsletter5@email.com')
            ]
            for newsletter in newsletters:
                db.session.add(newsletter)
            
            db.session.commit()
            print("Database initialized with sample data!")
except Exception as e:
    print(f"Database initialization error: {str(e)}")

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)