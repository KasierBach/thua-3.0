from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import psycopg2
import psycopg2.extras
import os
from datetime import datetime
import decimal
import json
import re
from datetime import datetime, timedelta
import uuid
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'fashion_store_secret_key')

# Cấu hình kết nối PostgreSQL
database_url = os.environ.get('DATABASE_URL')
if not database_url:
    # Cấu hình local development
    database_url = 'postgresql://username:password@localhost:5432/fashionstoredb'

# Fix for Render's DATABASE_URL format
if database_url.startswith('postgres://'):
    database_url = database_url.replace('postgres://', 'postgresql://', 1)

app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Cấu hình email
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', 'your_email@gmail.com')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', 'your_app_password')
EMAIL_USE_TLS = True

db = SQLAlchemy(app)

# Hàm kết nối trực tiếp đến PostgreSQL
def get_db_connection():
    conn = psycopg2.connect(database_url)
    return conn

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

# Trang chủ
@app.route('/')
def home():
    # Lấy danh sách danh mục
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT * FROM Categories')
    categories = cursor.fetchall()
    
    # Lấy sản phẩm nổi bật (ví dụ: 8 sản phẩm mới nhất)
    cursor.execute('''
        SELECT p.ProductID, p.ProductName, p.Price, c.CategoryName, p.ImageURL,
        (SELECT ColorName FROM Colors cl JOIN ProductVariants pv ON cl.ColorID = pv.ColorID 
         WHERE pv.ProductID = p.ProductID LIMIT 1) AS FirstColor
        FROM Products p
        JOIN Categories c ON p.CategoryID = c.CategoryID
        ORDER BY p.CreatedAt DESC
        LIMIT 8
    ''')
    featured_products = cursor.fetchall()
    
    # Lấy sản phẩm bán chạy
    cursor.execute('''
        SELECT
        bs.ProductID,
        bs.ProductName,
        bs.Price,
        bs.CategoryName,
        bs.TotalSold,
        p.ImageURL
        FROM vw_BestSellingProducts bs
        JOIN Products p ON bs.ProductID = p.ProductID
        ORDER BY bs.TotalSold DESC
    ''')
    best_selling = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
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
    in_stock_only = request.args.get('in_stock', type=int, default=0)
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Lấy danh sách danh mục cho menu
    cursor.execute('SELECT * FROM Categories')
    categories = cursor.fetchall()
    
    # Lấy danh sách màu sắc cho bộ lọc
    cursor.execute('SELECT * FROM Colors')
    colors = cursor.fetchall()
    
    # Lấy danh sách kích thước cho bộ lọc
    cursor.execute('SELECT * FROM Sizes')
    sizes = cursor.fetchall()
    
    # Gọi function tìm kiếm sản phẩm
    cursor.execute('''
        SELECT * FROM sp_SearchProducts(%s, %s, %s, %s, %s, %s, %s)
    ''', (search_term, category_id, min_price, max_price, color_id, size_id, in_stock_only))
    
    products = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
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
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Lấy thông tin sản phẩm
    cursor.execute('''
        SELECT p.*, c.CategoryName 
        FROM Products p
        JOIN Categories c ON p.CategoryID = c.CategoryID
        WHERE p.ProductID = %s
    ''', (product_id,))
    product = cursor.fetchone()
    
    if not product:
        cursor.close()
        conn.close()
        flash('Sản phẩm không tồn tại', 'error')
        return redirect(url_for('products'))
    
    # Lấy các biến thể của sản phẩm (màu sắc, kích thước, số lượng)
    cursor.execute('''
        SELECT pv.VariantID, c.ColorID, c.ColorName, s.SizeID, s.SizeName, pv.Quantity
        FROM ProductVariants pv
        JOIN Colors c ON pv.ColorID = c.ColorID
        JOIN Sizes s ON pv.SizeID = s.SizeID
        WHERE pv.ProductID = %s
    ''', (product_id,))
    variants = cursor.fetchall()
    
    # Tổ chức các biến thể theo màu sắc và kích thước
    colors = {}
    sizes = {}
    variants_map = {}
    
    for variant in variants:
        color_id = variant['colorid']
        size_id = variant['sizeid']
        
        if color_id not in colors:
            colors[color_id] = {'id': color_id, 'name': variant['colorname']}
        
        if size_id not in sizes:
            sizes[size_id] = {'id': size_id, 'name': variant['sizename']}
        
        key = f"{color_id}_{size_id}"
        variants_map[key] = {
            'variant_id': variant['variantid'],
            'quantity': variant['quantity']
        }
    
    cursor.execute("""
    SELECT Rating, COUNT(*) as Count
    FROM Reviews
    WHERE ProductID = %s
    GROUP BY Rating
    """, (product_id,))
    raw_breakdown = cursor.fetchall()

    rating_breakdown = {i: 0 for i in range(1, 6)}
    for row in raw_breakdown:
        rating_breakdown[row['rating']] = row['count']

    cursor.close()
    conn.close()

    return render_template('product_detail.html', 
                          product=product,
                          original_price=product['price'] * decimal.Decimal('1.2'),
                          colors=list(colors.values()),
                          sizes=list(sizes.values()),
                          variants=variants_map,
                          rating_breakdown=rating_breakdown)

# Thêm vào giỏ hàng
@app.route('/add_to_cart', methods=['POST'])
def add_to_cart():
    variant_id = request.form.get('variant_id', type=int)
    quantity = request.form.get('quantity', type=int, default=1)
    
    if not variant_id:
        flash('Vui lòng chọn màu sắc và kích thước', 'error')
        return redirect(request.referrer)
    
    # Kiểm tra số lượng tồn kho
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('''
        SELECT pv.Quantity, p.ProductName, p.Price, c.ColorName, s.SizeName, p.ProductID, p.ImageURL
        FROM ProductVariants pv
        JOIN Products p ON pv.ProductID = p.ProductID
        JOIN Colors c ON pv.ColorID = c.ColorID
        JOIN Sizes s ON pv.SizeID = s.SizeID
        WHERE pv.VariantID = %s
    ''', (variant_id,))
    
    variant = cursor.fetchone()
    cursor.close()
    conn.close()
    
    if not variant:
        flash('Sản phẩm không tồn tại', 'error')
        return redirect(request.referrer)
    
    if variant['quantity'] < quantity:
        flash(f'Chỉ còn {variant["quantity"]} sản phẩm trong kho', 'error')
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
            'product_id': variant['productid'],
            'product_name': variant['productname'],
            'price': float(variant['price']),
            'color': variant['colorname'],
            'size': variant['sizename'],
            'quantity': quantity,
            'image_url': variant['imageurl']
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

# Thêm route mới cho chức năng "Mua ngay" sau route view_cart
@app.route('/buy_now', methods=['POST'])
def buy_now():
    variant_id = request.form.get('variant_id', type=int)
    quantity = request.form.get('quantity', type=int, default=1)
    
    if not variant_id:
        flash('Vui lòng chọn màu sắc và kích thước', 'error')
        return redirect(request.referrer)
    
    # Kiểm tra số lượng tồn kho
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('''
        SELECT pv.Quantity, p.ProductName, p.Price, c.ColorName, s.SizeName, p.ProductID, p.ImageURL
        FROM ProductVariants pv
        JOIN Products p ON pv.ProductID = p.ProductID
        JOIN Colors c ON pv.ColorID = c.ColorID
        JOIN Sizes s ON pv.SizeID = s.SizeID
        WHERE pv.VariantID = %s
    ''', (variant_id,))
    
    variant = cursor.fetchone()
    cursor.close()
    conn.close()
    
    if not variant:
        flash('Sản phẩm không tồn tại', 'error')
        return redirect(request.referrer)
    
    if variant['quantity'] < quantity:
        flash(f'Chỉ còn {variant["quantity"]} sản phẩm trong kho', 'error')
        return redirect(request.referrer)
    
    # Tạo giỏ hàng tạm thời cho phiên mua ngay
    temp_cart = [{
        'variant_id': variant_id,
        'product_id': variant['productid'],
        'product_name': variant['productname'],
        'price': float(variant['price']),
        'color': variant['colorname'],
        'size': variant['sizename'],
        'quantity': quantity,
        'image_url': variant['imageurl']
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
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cursor.execute('SELECT Quantity FROM ProductVariants WHERE VariantID = %s', (variant_id,))
    available = cursor.fetchone()
    cursor.close()
    conn.close()
    
    if not available or available['quantity'] < quantity:
        return jsonify({'success': False, 'message': f'Chỉ còn {available["quantity"]} sản phẩm trong kho'})
    
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
            # Nếu chưa đăng nhập, chuyển hướng đến trang đăng nhập
            flash('Vui lòng đăng nhập để tiếp tục thanh toán', 'error')
            return redirect(url_for('login', next=url_for('checkout')))
        
        # Lấy thông tin từ form
        shipping_address = request.form.get('shipping_address')
        payment_method = request.form.get('payment_method')
        
        if not shipping_address or not payment_method:
            flash('Vui lòng điền đầy đủ thông tin giao hàng', 'error')
            return redirect(url_for('checkout'))
        
        # Tạo đơn hàng mới
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Tính tổng tiền
        total_amount = sum(item['price'] * item['quantity'] for item in cart)
        
        # Gọi function tạo đơn hàng
        cursor.execute('''
            SELECT sp_CreateOrder(%s, %s, %s) as order_id
        ''', (session['user_id'], payment_method, shipping_address))
        
        result = cursor.fetchone()
        order_id = result['order_id']
        
        # Thêm chi tiết đơn hàng
        for item in cart:
            cursor.execute('''
                SELECT sp_AddOrderDetail(%s, %s, %s)
            ''', (order_id, item['variant_id'], item['quantity']))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        # Xóa giỏ hàng sau khi đặt hàng thành công
        if buy_now and 'temp_cart' in session:
            session.pop('temp_cart', None)
        else:
            session.pop('cart', None)
        
        flash('Đặt hàng thành công! Cảm ơn bạn đã mua sắm.', 'success')
        return redirect(url_for('order_confirmation', order_id=order_id))
    
    # Tính tổng tiền
    total = sum(item['price'] * item['quantity'] for item in cart)
    
    # Nếu đã đăng nhập, lấy thông tin địa chỉ của khách hàng
    address = ''
    if 'user_id' in session:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute('SELECT Address FROM Customers WHERE CustomerID = %s', (session['user_id'],))
        customer = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if customer and customer['address']:
            address = customer['address']
    
    return render_template('checkout.html', cart=cart, total=total, address=address)

# Trang xác nhận đơn hàng
@app.route('/order_confirmation/<int:order_id>')
def order_confirmation(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Lấy thông tin đơn hàng
    cursor.execute('''
        SELECT * FROM sp_GetOrderDetails(%s)
    ''', (order_id,))
    
    order = cursor.fetchone()
    
    # Lấy chi tiết đơn hàng
    cursor.execute('''
        SELECT od.OrderDetailID, p.ProductID, p.ProductName, c.ColorName, s.SizeName,
               od.Quantity, od.Price, (od.Quantity * od.Price) AS Subtotal
        FROM OrderDetails od
        JOIN ProductVariants pv ON od.VariantID = pv.VariantID
        JOIN Products p ON pv.ProductID = p.ProductID
        JOIN Colors c ON pv.ColorID = c.ColorID
        JOIN Sizes s ON pv.SizeID = s.SizeID
        WHERE od.OrderID = %s
    ''', (order_id,))
    order_details = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    if not order or order['customerid'] != session['user_id']:
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền xem', 'error')
        return redirect(url_for('home'))
    
    return render_template('order_confirmation.html', order=order, order_details=order_details)

# Trang đăng nhập
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        
        if not email or not password:
            flash('Vui lòng nhập email và mật khẩu', 'error')
            return redirect(url_for('login'))
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute('SELECT CustomerID, FullName, Password, DarkModeEnabled FROM Customers WHERE Email = %s', (email,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not user or not check_password_hash(user['password'], password):
            flash('Email hoặc mật khẩu không đúng', 'error')
            return redirect(url_for('login'))
        
        # Lưu thông tin đăng nhập vào session
        session['user_id'] = user['customerid']
        session['user_name'] = user['fullname']
        session['dark_mode'] = user['darkmodeenabled']
        
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
        
        # Mã hóa mật khẩu
        hashed_password = generate_password_hash(password)
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        try:
            # Gọi function thêm khách hàng mới
            cursor.execute('''
                SELECT sp_AddCustomer(%s, %s, %s, %s, %s) as customer_id
            ''', (full_name, email, hashed_password, phone, address))
            
            result = cursor.fetchone()
            customer_id = result['customer_id']
            
            conn.commit()
            
            # Đăng nhập tự động sau khi đăng ký
            session['user_id'] = customer_id
            session['user_name'] = full_name
            session['dark_mode'] = False
            
            flash('Đăng ký thành công!', 'success')
            return redirect(url_for('home'))
            
        except psycopg2.Error as e:
            conn.rollback()
            error_message = str(e)
            if 'Email đã tồn tại' in error_message:
                flash('Email đã được sử dụng, vui lòng chọn email khác', 'error')
            elif 'Số điện thoại đã tồn tại' in error_message:
                flash('Số điện thoại đã được sử dụng, vui lòng chọn số khác', 'error')
            else:
                flash('Đã xảy ra lỗi, vui lòng thử lại', 'error')
            
            return redirect(url_for('register'))
        finally:
            cursor.close()
            conn.close()
    
    return render_template('register.html')

# Đăng xuất
@app.route('/logout')
def logout():
    session.pop('user_id', None)
    session.pop('user_name', None)
    session.pop('dark_mode', None)
    session.pop('is_admin', None)
    flash('Đã đăng xuất thành công', 'success')
    return redirect(url_for('home'))

# Trang tài khoản của tôi
@app.route('/my_account')
def my_account():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Lấy thông tin khách hàng
    cursor.execute('SELECT * FROM Customers WHERE CustomerID = %s', (session['user_id'],))
    customer = cursor.fetchone()
    
    # Lấy danh sách đơn hàng
    cursor.execute('''
        SELECT * FROM sp_GetCustomerOrders(%s)
    ''', (session['user_id'],))
    
    orders = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('my_account.html', customer=customer, orders=orders)

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
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE Customers
            SET FullName = %s, PhoneNumber = %s
            WHERE CustomerID = %s
        ''', (full_name, phone, session['user_id']))
        
        conn.commit()
        
        # Cập nhật tên hiển thị trong session
        session['user_name'] = full_name
        
        flash('Cập nhật thông tin thành công!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    finally:
        cursor.close()
        conn.close()
    
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
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE Customers
            SET Address = %s
            WHERE CustomerID = %s
        ''', (address, session['user_id']))
        
        conn.commit()
        flash('Cập nhật địa chỉ thành công!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    finally:
        cursor.close()
        conn.close()
    
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
    if not re.match(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$', new_password):
        flash('Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số', 'error')
        return redirect(url_for('my_account', _anchor='password', password_error='Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Kiểm tra mật khẩu hiện tại
    cursor.execute('SELECT Password FROM Customers WHERE CustomerID = %s', (session['user_id'],))
    user = cursor.fetchone()
    
    if not user or not check_password_hash(user['password'], current_password):
        cursor.close()
        conn.close()
        flash('Mật khẩu hiện tại không đúng', 'error')
        return redirect(url_for('my_account', _anchor='password', password_error='Mật khẩu hiện tại không đúng'))
    
    # Cập nhật mật khẩu mới
    hashed_password = generate_password_hash(new_password)
    
    try:
        cursor.execute('''
            UPDATE Customers
            SET Password = %s
            WHERE CustomerID = %s
        ''', (hashed_password, session['user_id']))
        
        conn.commit()
        flash('Đổi mật khẩu thành công!', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    finally:
        cursor.close()
        conn.close()
    
    return redirect(url_for('my_account', _anchor='password', password_updated=True))

# Chi tiết đơn hàng
@app.route('/order_detail/<int:order_id>')
def order_detail(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Lấy thông tin đơn hàng
    cursor.execute('''
        SELECT * FROM sp_GetOrderDetails(%s)
    ''', (order_id,))
    
    order = cursor.fetchone()
    
    if not order or order['customerid'] != session['user_id']:
        cursor.close()
        conn.close()
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền xem', 'error')
        return redirect(url_for('my_account'))
    
    # Lấy chi tiết đơn hàng
    cursor.execute('''
        SELECT od.OrderDetailID, p.ProductID, p.ProductName, c.ColorName, s.SizeName,
               od.Quantity, od.Price, (od.Quantity * od.Price) AS Subtotal, p.ImageURL
        FROM OrderDetails od
        JOIN ProductVariants pv ON od.VariantID = pv.VariantID
        JOIN Products p ON pv.ProductID = p.ProductID
        JOIN Colors c ON pv.ColorID = c.ColorID
        JOIN Sizes s ON pv.SizeID = s.SizeID
        WHERE od.OrderID = %s
    ''', (order_id,))
    order_details = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('order_detail.html', order=order, order_details=order_details)

# Hủy đơn hàng
@app.route('/cancel_order/<int:order_id>', methods=['POST'])
def cancel_order(order_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Kiểm tra quyền sở hữu đơn hàng và trạng thái
    cursor.execute('''
        SELECT CustomerID, Status
        FROM Orders
        WHERE OrderID = %s
    ''', (order_id,))
    
    order = cursor.fetchone()
    
    if not order or order['customerid'] != session['user_id']:
        cursor.close()
        conn.close()
        flash('Đơn hàng không tồn tại hoặc bạn không có quyền hủy', 'error')
        return redirect(url_for('my_account'))
    
    if order['status'] not in ['Pending', 'Processing']:
        cursor.close()
        conn.close()
        flash('Không thể hủy đơn hàng ở trạng thái này', 'error')
        return redirect(url_for('order_detail', order_id=order_id))
    
    try:
        # Gọi function cập nhật trạng thái đơn hàng
        cursor.execute('''
            SELECT sp_UpdateOrderStatus(%s, %s)
        ''', (order_id, 'Cancelled'))
        
        conn.commit()
        flash('Đã hủy đơn hàng thành công', 'success')
    except Exception as e:
        conn.rollback()
        flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    finally:
        cursor.close()
        conn.close()
    
    return redirect(url_for('order_detail', order_id=order_id))

# Trang quên mật khẩu
@app.route('/forgot_password', methods=['GET', 'POST'])
def forgot_password():
    if request.method == 'POST':
        email = request.form.get('email')
        
        if not email:
            flash('Vui lòng nhập email', 'error')
            return redirect(url_for('forgot_password'))
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        # Kiểm tra email có tồn tại không
        cursor.execute('SELECT CustomerID, FullName FROM Customers WHERE Email = %s', (email,))
        customer = cursor.fetchone()
        
        if not customer:
            flash('Email không tồn tại trong hệ thống', 'error')
            cursor.close()
            conn.close()
            return redirect(url_for('forgot_password'))
        
        # Tạo token reset password
        token = str(uuid.uuid4())
        expiry_date = datetime.now() + timedelta(hours=1)  # Token có hiệu lực trong 1 giờ
        
        try:
            # Lưu token vào database
            cursor.execute('''
                INSERT INTO PasswordResetTokens (CustomerID, Token, ExpiryDate)
                VALUES (%s, %s, %s)
            ''', (customer['customerid'], token, expiry_date))
            
            conn.commit()
            
            # Gửi email reset password
            reset_link = url_for('reset_password', token=token, _external=True)
            html_content = f'''
            <h2>Đặt lại mật khẩu</h2>
            <p>Xin chào {customer['fullname']},</p>
            <p>Bạn đã yêu cầu đặt lại mật khẩu. Vui lòng click vào link bên dưới để đặt lại mật khẩu:</p>
            <p><a href="{reset_link}">Đặt lại mật khẩu</a></p>
            <p>Link này sẽ hết hiệu lực sau 1 giờ.</p>
            <p>Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
            '''
            
            if send_email(email, 'Đặt lại mật khẩu - Fashion Store', html_content):
                flash('Đã gửi link đặt lại mật khẩu đến email của bạn', 'success')
            else:
                flash('Không thể gửi email. Vui lòng thử lại sau.', 'error')
                
        except Exception as e:
            conn.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
        finally:
            cursor.close()
            conn.close()
        
        return redirect(url_for('login'))
    
    return render_template('forgot_password.html')

# Trang đặt lại mật khẩu
@app.route('/reset_password/<token>', methods=['GET', 'POST'])
def reset_password(token):
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Kiểm tra token có hợp lệ không
    cursor.execute('''
        SELECT prt.CustomerID, c.FullName, c.Email
        FROM PasswordResetTokens prt
        JOIN Customers c ON prt.CustomerID = c.CustomerID
        WHERE prt.Token = %s AND prt.ExpiryDate > %s AND prt.IsUsed = FALSE
    ''', (token, datetime.now()))
    
    token_data = cursor.fetchone()
    
    if not token_data:
        cursor.close()
        conn.close()
        flash('Link đặt lại mật khẩu không hợp lệ hoặc đã hết hạn', 'error')
        return redirect(url_for('forgot_password'))
    
    if request.method == 'POST':
        new_password = request.form.get('new_password')
        confirm_password = request.form.get('confirm_password')
        
        if not new_password or not confirm_password:
            flash('Vui lòng điền đầy đủ thông tin', 'error')
            return redirect(url_for('reset_password', token=token))
        
        if new_password != confirm_password:
            flash('Mật khẩu xác nhận không khớp', 'error')
            return redirect(url_for('reset_password', token=token))
        
        # Kiểm tra độ mạnh mật khẩu
        if not re.match(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$', new_password):
            flash('Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số', 'error')
            return redirect(url_for('reset_password', token=token))
        
        # Cập nhật mật khẩu mới
        hashed_password = generate_password_hash(new_password)
        
        try:
            # Cập nhật mật khẩu
            cursor.execute('''
                UPDATE Customers
                SET Password = %s
                WHERE CustomerID = %s
            ''', (hashed_password, token_data['customerid']))
            
            # Đánh dấu token đã được sử dụng
            cursor.execute('''
                UPDATE PasswordResetTokens
                SET IsUsed = TRUE
                WHERE Token = %s
            ''', (token,))
            
            conn.commit()
            flash('Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.', 'success')
            
            cursor.close()
            conn.close()
            return redirect(url_for('login'))
            
        except Exception as e:
            conn.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    cursor.close()
    conn.close()
    return render_template('reset_password.html', token=token, customer=token_data)

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
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT INTO ContactMessages (Name, Email, Subject, Message)
                VALUES (%s, %s, %s, %s)
            ''', (name, email, subject, message))
            
            conn.commit()
            flash('Cảm ơn bạn đã liên hệ! Chúng tôi sẽ phản hồi sớm nhất có thể.', 'success')
        except Exception as e:
            conn.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
        finally:
            cursor.close()
            conn.close()
        
        return redirect(url_for('contact'))
    
    return render_template('contact.html')

# Đăng ký nhận tin
@app.route('/subscribe_newsletter', methods=['POST'])
def subscribe_newsletter():
    email = request.form.get('email')
    
    if not email:
        return jsonify({'success': False, 'message': 'Vui lòng nhập email'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO NewsletterSubscribers (Email)
            VALUES (%s)
            ON CONFLICT (Email) DO UPDATE SET
            IsActive = TRUE,
            SubscribeDate = NOW()
        ''', (email,))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Đăng ký nhận tin thành công!'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Thêm/xóa sản phẩm yêu thích
@app.route('/toggle_wishlist', methods=['POST'])
def toggle_wishlist():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    product_id = request.form.get('product_id', type=int)
    
    if not product_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Kiểm tra xem sản phẩm đã có trong wishlist chưa
    cursor.execute('''
        SELECT WishlistID FROM Wishlist
        WHERE CustomerID = %s AND ProductID = %s
    ''', (session['user_id'], product_id))
    
    existing = cursor.fetchone()
    
    try:
        if existing:
            # Xóa khỏi wishlist
            cursor.execute('''
                DELETE FROM Wishlist
                WHERE CustomerID = %s AND ProductID = %s
            ''', (session['user_id'], product_id))
            message = 'Đã xóa khỏi danh sách yêu thích'
            is_in_wishlist = False
        else:
            # Thêm vào wishlist
            cursor.execute('''
                INSERT INTO Wishlist (CustomerID, ProductID)
                VALUES (%s, %s)
            ''', (session['user_id'], product_id))
            message = 'Đã thêm vào danh sách yêu thích'
            is_in_wishlist = True
        
        conn.commit()
        return jsonify({
            'success': True, 
            'message': message,
            'is_in_wishlist': is_in_wishlist
        })
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Trang danh sách yêu thích
@app.route('/wishlist')
def wishlist():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT w.WishlistID, p.ProductID, p.ProductName, p.Price, p.ImageURL,
               c.CategoryName, w.AddedDate
        FROM Wishlist w
        JOIN Products p ON w.ProductID = p.ProductID
        JOIN Categories c ON p.CategoryID = c.CategoryID
        WHERE w.CustomerID = %s
        ORDER BY w.AddedDate DESC
    ''', (session['user_id'],))
    
    wishlist_items = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
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
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO Reviews (CustomerID, ProductID, Rating, Comment)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (CustomerID, ProductID) DO UPDATE SET
            Rating = EXCLUDED.Rating,
            Comment = EXCLUDED.Comment,
            ReviewDate = NOW()
        ''', (session['user_id'], product_id, rating, comment))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Đánh giá đã được gửi thành công!'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Thêm bình luận sản phẩm
@app.route('/add_comment', methods=['POST'])
def add_comment():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    product_id = request.form.get('product_id', type=int)
    content = request.form.get('content', '').strip()
    
    if not product_id or not content:
        return jsonify({'success': False, 'message': 'Vui lòng nhập nội dung bình luận'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO ProductComments (CustomerID, ProductID, Content)
            VALUES (%s, %s, %s)
        ''', (session['user_id'], product_id, content))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Bình luận đã được gửi thành công!'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Lấy bình luận sản phẩm
@app.route('/get_comments/<int:product_id>')
def get_comments(product_id):
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT pc.CommentID, pc.Content, pc.CommentDate, pc.AdminReply, pc.ReplyDate,
               c.FullName as CustomerName
        FROM ProductComments pc
        JOIN Customers c ON pc.CustomerID = c.CustomerID
        WHERE pc.ProductID = %s AND pc.IsVisible = TRUE
        ORDER BY pc.CommentDate DESC
    ''', (product_id,))
    
    comments = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    # Chuyển đổi datetime thành string để JSON serialize
    for comment in comments:
        comment['commentdate'] = comment['commentdate'].strftime('%d/%m/%Y %H:%M')
        if comment['replydate']:
            comment['replydate'] = comment['replydate'].strftime('%d/%m/%Y %H:%M')
    
    return jsonify(comments)

# Lấy đánh giá sản phẩm
@app.route('/get_reviews/<int:product_id>')
def get_reviews(product_id):
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT r.ReviewID, r.Rating, r.Comment, r.ReviewDate,
               c.FullName as CustomerName
        FROM Reviews r
        JOIN Customers c ON r.CustomerID = c.CustomerID
        WHERE r.ProductID = %s
        ORDER BY r.ReviewDate DESC
    ''', (product_id,))
    
    reviews = cursor.fetchall()
    
    # Tính điểm trung bình
    cursor.execute('''
        SELECT AVG(Rating)::DECIMAL(3,2) as avg_rating, COUNT(*) as total_reviews
        FROM Reviews
        WHERE ProductID = %s
    ''', (product_id,))
    
    stats = cursor.fetchone()
    
    cursor.close()
    conn.close()
    
    # Chuyển đổi datetime thành string để JSON serialize
    for review in reviews:
        review['reviewdate'] = review['reviewdate'].strftime('%d/%m/%Y %H:%M')
    
    return jsonify({
        'reviews': reviews,
        'avg_rating': float(stats['avg_rating']) if stats['avg_rating'] else 0,
        'total_reviews': stats['total_reviews']
    })

# Bật/tắt chế độ tối
@app.route('/toggle_dark_mode', methods=['POST'])
def toggle_dark_mode():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Vui lòng đăng nhập'})
    
    # Đảo ngược trạng thái dark mode
    current_mode = session.get('dark_mode', False)
    new_mode = not current_mode
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE Customers
            SET DarkModeEnabled = %s
            WHERE CustomerID = %s
        ''', (new_mode, session['user_id']))
        
        conn.commit()
        
        # Cập nhật session
        session['dark_mode'] = new_mode
        
        return jsonify({
            'success': True, 
            'dark_mode': new_mode,
            'message': f'Đã {"bật" if new_mode else "tắt"} chế độ tối'
        })
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# ===== ADMIN ROUTES =====

# Kiểm tra quyền admin
def admin_required(f):
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            flash('Vui lòng đăng nhập', 'error')
            return redirect(url_for('login'))
        
        # Kiểm tra email admin (có thể thay đổi theo nhu cầu)
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cursor.execute('SELECT Email FROM Customers WHERE CustomerID = %s', (session['user_id'],))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not user or user['email'] != 'admin@fashionstore.com':
            flash('Bạn không có quyền truy cập trang này', 'error')
            return redirect(url_for('home'))
        
        session['is_admin'] = True
        return f(*args, **kwargs)
    
    decorated_function.__name__ = f.__name__
    return decorated_function

# Trang quản trị chính
@app.route('/admin')
@admin_required
def admin_dashboard():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Thống kê tổng quan
    cursor.execute('SELECT COUNT(*) as total FROM Products')
    total_products = cursor.fetchone()['total']
    
    cursor.execute('SELECT COUNT(*) as total FROM Orders')
    total_orders = cursor.fetchone()['total']
    
    cursor.execute('SELECT COUNT(*) as total FROM Customers')
    total_customers = cursor.fetchone()['total']
    
    cursor.execute('''
        SELECT COALESCE(SUM(TotalAmount), 0) as total
        FROM Orders
        WHERE Status NOT IN ('Cancelled')
    ''')
    total_revenue = cursor.fetchone()['total']
    
    # Đơn hàng gần đây
    cursor.execute('''
        SELECT o.OrderID, c.FullName, o.OrderDate, o.TotalAmount, o.Status
        FROM Orders o
        JOIN Customers c ON o.CustomerID = c.CustomerID
        ORDER BY o.OrderDate DESC
        LIMIT 10
    ''')
    recent_orders = cursor.fetchall()
    
    # Sản phẩm bán chạy
    cursor.execute('''
        SELECT * FROM vw_BestSellingProducts
        LIMIT 5
    ''')
    best_selling = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/dashboard.html',
                          total_products=total_products,
                          total_orders=total_orders,
                          total_customers=total_customers,
                          total_revenue=total_revenue,
                          recent_orders=recent_orders,
                          best_selling=best_selling)

# Quản lý sản phẩm
@app.route('/admin/products')
@admin_required
def admin_products():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT p.ProductID, p.ProductName, p.Price, c.CategoryName, p.CreatedAt,
               COALESCE(SUM(pv.Quantity), 0) as TotalStock
        FROM Products p
        JOIN Categories c ON p.CategoryID = c.CategoryID
        LEFT JOIN ProductVariants pv ON p.ProductID = pv.ProductID
        GROUP BY p.ProductID, p.ProductName, p.Price, c.CategoryName, p.CreatedAt
        ORDER BY p.CreatedAt DESC
    ''')
    products = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/products.html', products=products)

# Chỉnh sửa sản phẩm
@app.route('/admin/edit_product/<int:product_id>', methods=['GET', 'POST'])
@admin_required
def admin_edit_product(product_id):
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    if request.method == 'POST':
        product_name = request.form.get('product_name')
        description = request.form.get('description')
        price = request.form.get('price', type=float)
        category_id = request.form.get('category_id', type=int)
        
        try:
            cursor.execute('''
                UPDATE Products
                SET ProductName = %s, Description = %s, Price = %s, CategoryID = %s
                WHERE ProductID = %s
            ''', (product_name, description, price, category_id, product_id))
            
            conn.commit()
            flash('Cập nhật sản phẩm thành công!', 'success')
            return redirect(url_for('admin_products'))
        except Exception as e:
            conn.rollback()
            flash(f'Đã xảy ra lỗi: {str(e)}', 'error')
    
    # Lấy thông tin sản phẩm
    cursor.execute('SELECT * FROM Products WHERE ProductID = %s', (product_id,))
    product = cursor.fetchone()
    
    # Lấy danh sách danh mục
    cursor.execute('SELECT * FROM Categories')
    categories = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    if not product:
        flash('Sản phẩm không tồn tại', 'error')
        return redirect(url_for('admin_products'))
    
    return render_template('admin/edit_product.html', product=product, categories=categories)

# Quản lý đơn hàng
@app.route('/admin/orders')
@admin_required
def admin_orders():
    status_filter = request.args.get('status', '')
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    query = '''
        SELECT o.OrderID, c.FullName, c.Email, o.OrderDate, o.TotalAmount, o.Status, o.PaymentMethod
        FROM Orders o
        JOIN Customers c ON o.CustomerID = c.CustomerID
    '''
    params = []
    
    if status_filter:
        query += ' WHERE o.Status = %s'
        params.append(status_filter)
    
    query += ' ORDER BY o.OrderDate DESC'
    
    cursor.execute(query, params)
    orders = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/orders.html', orders=orders, status_filter=status_filter)

# Cập nhật trạng thái đơn hàng
@app.route('/admin/update_order_status', methods=['POST'])
@admin_required
def admin_update_order_status():
    order_id = request.form.get('order_id', type=int)
    new_status = request.form.get('status')
    
    if not order_id or not new_status:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Gọi function cập nhật trạng thái đơn hàng
        cursor.execute('''
            SELECT sp_UpdateOrderStatus(%s, %s)
        ''', (order_id, new_status))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Cập nhật trạng thái thành công'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Báo cáo doanh thu
@app.route('/admin/reports')
@admin_required
def admin_reports():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    # Doanh thu theo tháng
    cursor.execute('SELECT * FROM vw_MonthlyRevenue LIMIT 12')
    monthly_revenue = cursor.fetchall()
    
    # Doanh thu theo danh mục
    cursor.execute('SELECT * FROM vw_CategoryRevenue')
    category_revenue = cursor.fetchall()
    
    # Doanh thu 7 ngày gần đây
    cursor.execute('''
        SELECT * FROM sp_GetRevenueByDateRange(%s, %s)
    ''', (datetime.now().date() - timedelta(days=6), datetime.now().date()))
    daily_revenue = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/reports.html',
                          monthly_revenue=monthly_revenue,
                          category_revenue=category_revenue,
                          daily_revenue=daily_revenue)

# Quản lý tin nhắn liên hệ
@app.route('/admin/contact_messages')
@admin_required
def admin_contact_messages():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT * FROM ContactMessages
        ORDER BY SubmitDate DESC
    ''')
    messages = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/contact_messages.html', messages=messages)

# Cập nhật trạng thái tin nhắn liên hệ
@app.route('/admin/update_message_status', methods=['POST'])
@admin_required
def admin_update_message_status():
    message_id = request.form.get('message_id', type=int)
    new_status = request.form.get('status')
    
    if not message_id or not new_status:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE ContactMessages
            SET Status = %s
            WHERE MessageID = %s
        ''', (new_status, message_id))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Cập nhật trạng thái thành công'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Quản lý bình luận
@app.route('/admin/comments')
@admin_required
def admin_comments():
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    cursor.execute('''
        SELECT pc.CommentID, pc.Content, pc.CommentDate, pc.AdminReply, pc.ReplyDate, pc.IsVisible,
               c.FullName as CustomerName, p.ProductName
        FROM ProductComments pc
        JOIN Customers c ON pc.CustomerID = c.CustomerID
        JOIN Products p ON pc.ProductID = p.ProductID
        ORDER BY pc.CommentDate DESC
    ''')
    comments = cursor.fetchall()
    
    cursor.close()
    conn.close()
    
    return render_template('admin/comments.html', comments=comments)

# Trả lời bình luận
@app.route('/admin/reply_comment', methods=['POST'])
@admin_required
def admin_reply_comment():
    comment_id = request.form.get('comment_id', type=int)
    reply = request.form.get('reply', '').strip()
    
    if not comment_id or not reply:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            UPDATE ProductComments
            SET AdminReply = %s, ReplyDate = NOW()
            WHERE CommentID = %s
        ''', (reply, comment_id))
        
        conn.commit()
        return jsonify({'success': True, 'message': 'Trả lời bình luận thành công'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

# Ẩn/hiện bình luận
@app.route('/admin/toggle_comment_visibility', methods=['POST'])
@admin_required
def admin_toggle_comment_visibility():
    comment_id = request.form.get('comment_id', type=int)
    
    if not comment_id:
        return jsonify({'success': False, 'message': 'Dữ liệu không hợp lệ'})
    
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    try:
        # Lấy trạng thái hiện tại
        cursor.execute('SELECT IsVisible FROM ProductComments WHERE CommentID = %s', (comment_id,))
        current = cursor.fetchone()
        
        if not current:
            return jsonify({'success': False, 'message': 'Bình luận không tồn tại'})
        
        new_visibility = not current['isvisible']
        
        cursor.execute('''
            UPDATE ProductComments
            SET IsVisible = %s
            WHERE CommentID = %s
        ''', (new_visibility, comment_id))
        
        conn.commit()
        
        action = 'hiện' if new_visibility else 'ẩn'
        return jsonify({'success': True, 'message': f'Đã {action} bình luận'})
    except Exception as e:
        conn.rollback()
        return jsonify({'success': False, 'message': f'Đã xảy ra lỗi: {str(e)}'})
    finally:
        cursor.close()
        conn.close()

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
    return render_template('500.html'), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)