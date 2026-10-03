import 'package:flutter/material.dart';

import '../database/database.dart';
import 'login_page.dart';

class WebsitePage extends StatefulWidget {
  static const id = 'website-page';
  const WebsitePage({super.key});

  @override
  State<WebsitePage> createState() => _WebsitePageState();
}

class _WebsitePageState extends State<WebsitePage> {
  int page = 0;
  String category = 'All devices';
  List<_Product> products = [];
  bool isLoading = false;
  _Product? selectedProduct;
  bool selectedForShop = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    try {
      final fetched = await Db.get('items');
      final items = (fetched as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      setState(() {
        products = items.map(_Product.fromMap).toList();
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void go(int value) => setState(() {
    page = value;
    if (value != 5) selectedProduct = null;
  });

  void showProductDetails(_Product product, bool shop) => setState(() {
    selectedProduct = product;
    selectedForShop = shop;
    page = 5;
  });
  void login({bool register = false}) =>
      Navigator.pushNamed(
        context,
        LoginPage.id,
        arguments: LoginOptions(register: register),
      );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 780;
    return Scaffold(
      backgroundColor: const Color(0xfff6f9ff),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: _Header(page: page, compact: compact, go: go, login: login),
      ),
      body: SingleChildScrollView(
        child: switch (page) {
          0 => _home(compact),
          1 => _catalog(compact, false),
          2 => _catalog(compact, true),
          3 => _about(compact),
          4 => _contact(compact),
          _ => _productDetails(compact),
        },
      ),
    );
  }

  Widget _home(bool compact) => Column(
    children: [
      Container(
        constraints: const BoxConstraints(minHeight: 485),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xffeaf2ff)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 58),
              child: Flex(
                direction: compact ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  compact ? _heroText() : Expanded(flex: 5, child: _heroText()),
                  SizedBox(width: compact ? 0 : 34, height: compact ? 38 : 0),
                  compact
                      ? _heroImage()
                      : Expanded(flex: 6, child: _heroImage()),
                ],
              ),
            ),
          ),
        ),
      ),
      _benefits(compact),
      _trustSection(compact),
      _sectionTitle(
        'Popular devices',
        'Choose the right equipment for your next project.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 64),
        child: isLoading && products.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff155eef)),
              )
            : products.isEmpty
            ? const Center(child: Text('No products available right now.'))
            : _grid(products.take(3).toList(), compact),
      ),
      _footer(compact),
    ],
  );

  Widget _heroText() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'RENT SMART. WORK BETTER.',
        style: TextStyle(
          color: Color(0xff155eef),
          fontSize: 13,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Laptops & Desktops\nmade simple your order.',
        style: TextStyle(
          fontSize: 48,
          height: 1.08,
          letterSpacing: -1.8,
          fontWeight: FontWeight.w800,
          color: Color(0xff0b1b45),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Gor Gor gives you dependable technology for work, school and business—delivered with flexible daily rental plans.',
        style: TextStyle(fontSize: 16, height: 1.65, color: Color(0xff52627e)),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _primary('Browse rentals', () => go(1)),
          _outline('How it works', () => go(3)),
        ],
      ),
    ],
  );

  Widget _heroImage() => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: SizedBox(
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&w=1200&q=85',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Color(0x99061d55), Colors.transparent],
              ),
            ),
          ),
          const Positioned(
            left: 24,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POWER FOR EVERY TASK',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Premium equipment, ready today',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _benefits(bool compact) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(26),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 24,
        children: const [
          _Benefit(
            Icons.verified_user_outlined,
            'Trusted & reliable',
            'Quality checked devices',
          ),
          _Benefit(
            Icons.payments_outlined,
            'Fair pricing',
            'Simple daily rates',
          ),
          _Benefit(
            Icons.calendar_month_outlined,
            'Flexible rental',
            'Book for any timeline',
          ),
          _Benefit(
            Icons.support_agent_outlined,
            '24/7 support',
            'We are here to help',
          ),
        ],
      ),
    ),
  );

  Widget _trustSection(bool compact) => Container(
    width: double.infinity,
    color: const Color(0xfff0f5ff),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            compact
                ? _trustIntro()
                : const Expanded(flex: 5, child: _TrustIntro()),
            SizedBox(width: compact ? 0 : 58, height: compact ? 34 : 0),
            compact ? _trustPoints() : Expanded(flex: 6, child: _trustPoints()),
          ],
        ),
      ),
    ),
  );

  Widget _trustIntro() => const _TrustIntro();

  Widget _trustPoints() => Column(
    children: const [
      _TrustPoint(
        Icons.laptop_mac_outlined,
        'Ready-to-work devices',
        'Every laptop and desktop is checked before it reaches you, so you can focus on your work from day one.',
      ),
      SizedBox(height: 16),
      _TrustPoint(
        Icons.verified_outlined,
        'Clear, honest service',
        'Simple booking, transparent daily pricing and a team that keeps you informed at every step.',
      ),
      SizedBox(height: 16),
      _TrustPoint(
        Icons.groups_2_outlined,
        'Built around your needs',
        'Whether it is for school, business or a short project, choose the equipment and rental period that fit you.',
      ),
    ],
  );

  Widget _catalog(bool compact, bool shop) {
    final shown = category == 'All devices'
        ? products
        : products.where((p) => p.type == category).toList();
    return Column(
      children: [
        _pageHeading(
          shop ? 'Online Shop' : 'Rental Shop',
          shop
              ? 'Choose a device to buy or reserve.'
              : 'Find dependable equipment for your work.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 70),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filter(),
                SizedBox(width: compact ? 0 : 28, height: compact ? 24 : 0),
                compact
                    ? (shown.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'No products found for this category.',
                              ),
                            )
                          : _grid(shown, compact, shop: shop))
                    : Expanded(
                        child: shown.isEmpty
                            ? const Center(
                                child: Text(
                                  'No products found for this category.',
                                ),
                              )
                            : _grid(shown, compact, shop: shop),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filter() => Container(
    width: 210,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xffe4eaf4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xff0b1b45),
          ),
        ),
        const SizedBox(height: 10),
        for (final c in ['All devices', 'Laptop', 'Desktop'])
          InkWell(
            onTap: () => setState(() => category = c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: category == c
                    ? const Color(0xffe8f0ff)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c,
                style: TextStyle(
                  color: category == c
                      ? const Color(0xff155eef)
                      : const Color(0xff52627e),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        const Divider(height: 32),
      ],
    ),
  );

  Widget _grid(List<_Product> shown, bool compact, {bool shop = false}) =>
      LayoutBuilder(
        builder: (context, c) {
          final n = c.maxWidth < 560
              ? 1
              : c.maxWidth < 900
              ? 2
              : 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n,
              childAspectRatio: .72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) => _productCard(shown[i], shop),
          );
        },
      );

  Widget _productCard(_Product p, bool shop) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe5ebf4)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _productImage(p),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            p.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xff0b1b45),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            p.type,
            style: const TextStyle(fontSize: 12, color: Color(0xff6b7890)),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Color(0xff0b1b45)),
              children: [
                TextSpan(
                  text: p.price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                TextSpan(
                  text: shop ? ' / purchase' : ' / day',
                  style: const TextStyle(
                    color: Color(0xff6b7890),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outline('View details', () => showProductDetails(p, shop)),
          ),
        ],
      ),
    ),
  );

  Widget _productDetails(bool compact) {
    final product = selectedProduct;
    if (product == null) return const SizedBox.shrink();

    return Column(
      children: [
        _pageHeading(
          selectedForShop ? 'Online Shop' : 'Rental Shop',
          'Device information and specifications.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 72),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => go(selectedForShop ? 2 : 1),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    selectedForShop ? 'Back to Online Shop' : 'Back to Rental',
                  ),
                ),
                const SizedBox(height: 12),
                Flex(
                  direction: compact ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    compact
                        ? _detailImage(product)
                        : Expanded(flex: 5, child: _detailImage(product)),
                    SizedBox(width: compact ? 0 : 42, height: compact ? 30 : 0),
                    compact
                        ? _detailContent(product)
                        : Expanded(flex: 6, child: _detailContent(product)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailImage(_Product product) => Container(
    height: 370,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffe5ebf4)),
    ),
    padding: const EdgeInsets.all(20),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: _productImage(product),
    ),
  );

  Widget _detailContent(_Product product) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xfff1f1f9),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: const Color(0xff1ab9ad),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          child: const Text(
            'PRODUCT DESCRIPTION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          product.description,
          style: const TextStyle(
            color: Color(0xff52627e),
            height: 1.55,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 24),
        _specification('Type', product.type),
        _specification('Processor', product.processor),
        _specification('Screen', product.screen),
        _specification('RAM', product.ram),
        _specification('Storage', product.storage),
        _specification('Charges', 'Charger included'),
        _specification(
          selectedForShop ? 'Purchase Price' : 'Rental Price',
          selectedForShop
              ? '\$${product.price}'
              : '\$${product.price} (per day)',
        ),
        _specification('Product Model', product.name),
        const SizedBox(height: 12),
        _primary(
          selectedForShop ? 'Book / Buy now' : 'Rent now',
          () => login(),
        ),
      ],
    ),
  );

  Widget _specification(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xff52627e), fontSize: 16),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Color(0xff0b1b45),
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _about(bool compact) => Column(
    children: [
      _pageHeading(
        'About Gor Gor',
        'Technology that helps your next idea take shape.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 72),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              compact ? _aboutVisual() : Expanded(child: _aboutVisual()),
              SizedBox(width: compact ? 0 : 56, height: compact ? 34 : 0),
              compact ? _aboutCopy() : Expanded(child: _aboutCopy()),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _contact(bool compact) => Column(
    children: [
      _pageHeading('Contact us', 'Let us help you find the perfect device.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 72),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xffdce8fc)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120b1b45),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                compact ? _contactInfo() : Expanded(child: _contactInfo()),
                SizedBox(width: compact ? 0 : 50, height: compact ? 32 : 0),
                compact ? _contactForm() : Expanded(child: _contactForm()),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _pageHeading(String title, String sub) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 46),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xffedf4ff), Color(0xfff9fbff)]),
    ),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Color(0xff0b1b45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          style: const TextStyle(color: Color(0xff52627e), fontSize: 16),
        ),
      ],
    ),
  );

  Widget _aboutVisual() => Container(
    height: 360,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffe7f0ff), Color(0xfff8fbff)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffd5e4ff)),
    ),
    child: Stack(
      children: [
        Center(child: Image.asset('images/logo.jpeg', fit: BoxFit.contain)),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xff0b1b45),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'TECHNOLOGY YOU CAN RELY ON',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _sectionTitle(String a, String b) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 58, 24, 24),
    child: Column(
      children: [
        Text(
          a,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 29,
            color: Color(0xff0b1b45),
          ),
        ),
        const SizedBox(height: 7),
        Text(b, style: const TextStyle(color: Color(0xff52627e))),
      ],
    ),
  );
  Widget _footer(bool compact) => Container(
    width: double.infinity,
    color: const Color(0xff061632),
    padding: const EdgeInsets.fromLTRB(28, 48, 28, 22),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Column(
          children: [
            const Text(
              'Ready to work without limits?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your account and reserve equipment in minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffcbd9f5)),
            ),
            const SizedBox(height: 22),
            _primary('Create an account', () => login(register: true)),
            const SizedBox(height: 54),
            Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                compact
                    ? _footerBrand()
                    : Expanded(flex: 4, child: _footerBrand()),
                SizedBox(width: compact ? 0 : 58, height: compact ? 34 : 0),
                compact
                    ? _footerLinks()
                    : Expanded(flex: 2, child: _footerLinks()),
                SizedBox(width: compact ? 0 : 42, height: compact ? 30 : 0),
                compact
                    ? _footerContact()
                    : Expanded(flex: 3, child: _footerContact()),
              ],
            ),
            const SizedBox(height: 38),
            const Divider(color: Color(0xff294264), height: 1),
            const SizedBox(height: 18),
            compact
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '© 2026 GOR GOR Tech Rental. All rights reserved.',
                        style: TextStyle(
                          color: Color(0xffaebed5),
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Reliable technology, made simple.',
                        style: TextStyle(
                          color: Color(0xffaebed5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© 2026 GOR GOR Tech Rental. All rights reserved.',
                        style: TextStyle(
                          color: Color(0xffaebed5),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Reliable technology, made simple.',
                        style: TextStyle(
                          color: Color(0xffaebed5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    ),
  );

  Widget _footerBrand() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset('images/logo.jpeg', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'GOR GOR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      const SizedBox(height: 15),
      const SizedBox(
        width: 315,
        child: Text(
          'Dependable laptops and desktops for work, study and business — ready when you are.',
          style: TextStyle(color: Color(0xffb6c5db), height: 1.55),
        ),
      ),
    ],
  );

  Widget _footerLinks() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'EXPLORE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      _footerLink('Rental shop', () => go(1)),
      _footerLink('Online shop', () => go(2)),
      _footerLink('About us', () => go(3)),
    ],
  );

  Widget _footerContact() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'CONTACT',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      SizedBox(height: 13),
      _FooterContact(Icons.location_on_outlined, 'Garowe, Somalia'),
      SizedBox(height: 10),
      _FooterContact(Icons.mail_outline, 'gorgor@.so'),
      SizedBox(height: 10),
      _FooterContact(Icons.call_outlined, '+252 90 7 261305'),
    ],
  );

  Widget _footerLink(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 5),
    ),
    child: Text(label, style: const TextStyle(color: Color(0xffb6c5db))),
  );
  Widget _primary(String text, VoidCallback callback) => ElevatedButton(
    onPressed: callback,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xff155eef),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
  Widget _outline(String text, VoidCallback callback) => OutlinedButton(
    onPressed: callback,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xff155eef),
      side: const BorderSide(color: Color(0xffb8cdf8)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
  Widget _field(String hint, {int max = 1}) => TextField(
    maxLines: max,
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xfff7f9fd),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
  );
  Widget _productImage(_Product product) => Image.network(
    product.image,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      color: const Color(0xffedf3ff),
      alignment: Alignment.center,
      child: Icon(
        product.type.toLowerCase().contains('desktop')
            ? Icons.desktop_windows_outlined
            : Icons.laptop_mac_outlined,
        color: const Color(0xff155eef),
        size: 48,
      ),
    ),
  );
  Widget _aboutCopy() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Built for people who need technology to simply work.',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 29,
          height: 1.18,
          color: Color(0xff0b1b45),
        ),
      ),
      SizedBox(height: 18),
      Text(
        'Gor Gor Laptop & Desktop Rental makes it easy to access quality devices without the cost and complexity of ownership.',
        style: TextStyle(height: 1.7, color: Color(0xff52627e), fontSize: 16),
      ),
      SizedBox(height: 25),
      _AboutItem(
        Icons.track_changes_outlined,
        'Our mission',
        'Affordable, dependable equipment for everyone.',
      ),
      _AboutItem(
        Icons.visibility_outlined,
        'Our vision',
        'To be Somalia’s most trusted technology partner.',
      ),
      _AboutItem(
        Icons.favorite_border,
        'Our values',
        'Honesty, quality and customer care.',
      ),
    ],
  );
  Widget _contactInfo() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff0a2360), Color(0xff155eef)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const _ContactInfo(),
  );

  Widget _contactForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Send us a message',
        style: TextStyle(
          color: Color(0xff0b1b45),
          fontSize: 23,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Tell us what device you need and our team will help you find the right option.',
        style: TextStyle(color: Color(0xff52627e), height: 1.45),
      ),
      const SizedBox(height: 22),
      _field('Your name'),
      const SizedBox(height: 13),
      _field('Email address'),
      const SizedBox(height: 13),
      _field('How can we help?', max: 4),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: _primary(
          'Send message',
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you — we will get back to you soon.'),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.compact,
    required this.go,
    required this.login,
  });
  final int page;
  final bool compact;
  final void Function(int) go;
  final void Function({bool register}) login;
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.white,
    titleSpacing: 28,
    title: Row(
      children: [
        // Use the project logo asset (place your provided image at images/logo.png)
        Image.asset('images/logo.png', height: 100, fit: BoxFit.contain),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'GOR GOR',
              style: TextStyle(
                color: Color(0xff0b1b45),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Laptop and Desktop Rental system',
              style: TextStyle(color: Color(0xff52627e), fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        if (!compact) ...[
          for (final e in [
            (0, 'Home'),
            (1, 'Rental'),
            (2, 'Online Shop'),
            (3, 'About'),
            (4, 'Contact'),
          ])
            TextButton(
              onPressed: () => go(e.$1),
              child: Text(
                e.$2,
                style: TextStyle(
                  color: page == e.$1
                      ? const Color(0xff155eef)
                      : const Color(0xff253451),
                  fontWeight: page == e.$1 ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => login(), child: const Text('Login')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => login(register: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff155eef),
              foregroundColor: Colors.white,
            ),
            child: const Text('Register'),
          ),
        ] else
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu, color: Color(0xff0b1b45)),
            onSelected: (v) {
              if (v == 5)
                login();
              else if (v == 6)
                login(register: true);
              else
                go(v);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Home')),
              PopupMenuItem(value: 1, child: Text('Rental')),
              PopupMenuItem(value: 2, child: Text('Online Shop')),
              PopupMenuItem(value: 3, child: Text('About')),
              PopupMenuItem(value: 4, child: Text('Contact')),
              PopupMenuDivider(),
              PopupMenuItem(value: 5, child: Text('Login')),
              PopupMenuItem(value: 6, child: Text('Register')),
            ],
          ),
      ],
    ),
  );
}

class _Product {
  final String name;
  final String type;
  final String price;
  final String image;
  final String details;
  final String brand;

  const _Product(
    this.name,
    this.type,
    this.price,
    this.image,
    this.details,
    this.brand,
  );

  String get description {
    if (details.trim().isNotEmpty) return details.trim();
    return '$name is a dependable $type prepared for work, school and business. '
        'It is quality checked and ready for everyday productivity, meetings and internet use.';
  }

  String get processor => _find(
    RegExp(
      r'(Intel\s+(?:Core\s+)?(?:i[3579]|Celeron|Pentium)[^,;\n]*|AMD\s+(?:Ryzen|Athlon)[^,;\n]*)',
      caseSensitive: false,
    ),
    'Intel Core i5',
  );

  String get screen => type == 'Desktop'
      ? _find(
          RegExp(
            r'(?:screen|display|monitor)\s*[:\-]?\s*([^,;\n]+)',
            caseSensitive: false,
          ),
          'Desktop monitor included',
        )
      : _find(
          RegExp(
            r'\b(1[345678]?(?:\.\d)?[- ]?(?:inch|in|"))',
            caseSensitive: false,
          ),
          '15.6-inch display',
        );

  String get ram => _find(
    RegExp(r'\b(\d{1,2}\s*GB\s*(?:RAM)?)', caseSensitive: false),
    '8 GB',
  );

  String get storage => _find(
    RegExp(r'\b(\d{2,4}\s*(?:GB|TB)\s*(?:SSD|HDD)?)', caseSensitive: false),
    '256 GB SSD',
  );

  String _find(RegExp expression, String fallback) {
    final match = expression.firstMatch('$name $brand $details');
    if (match == null) return fallback;
    return (match.groupCount > 0 ? match.group(1) : match.group(0))?.trim() ??
        fallback;
  }

  factory _Product.fromMap(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Product';
    final brand = item['brand']?.toString() ?? '';
    final details = item['details']?.toString() ?? '';
    final combined = '$name $brand $details'.toLowerCase();

    String type = 'Laptop';
    if (combined.contains('desktop') ||
        combined.contains('pc') ||
        combined.contains('station') ||
        combined.contains('imac') ||
        combined.contains('elite') ||
        combined.contains('optiplex')) {
      type = 'Desktop';
    }

    return _Product(
      name,
      type,
      item['price']?.toString() ?? '0',
      item['image']?.toString() ?? '',
      details,
      brand,
    );
  }
}

class _FooterContact extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FooterContact(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xff6da2ff), size: 18),
      const SizedBox(width: 9),
      Text(text, style: const TextStyle(color: Color(0xffb6c5db))),
    ],
  );
}

class _TrustIntro extends StatelessWidget {
  const _TrustIntro();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'YOUR RELIABLE TECHNOLOGY PARTNER',
        style: TextStyle(
          color: Color(0xff155eef),
          letterSpacing: 1.3,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 14),
      Text(
        'Technology you can trust, when you need it most.',
        style: TextStyle(
          color: Color(0xff0b1b45),
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w900,
        ),
      ),
      SizedBox(height: 18),
      Text(
        'GOR GOR Tech Rental makes it easy to get dependable laptops and desktops without the cost of ownership. We help students, professionals and businesses stay productive with equipment that is ready when they are.',
        style: TextStyle(color: Color(0xff52627e), fontSize: 16, height: 1.7),
      ),
    ],
  );
}

class _TrustPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TrustPoint(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffdce8fc)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xffe8f0ff),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xff155eef), size: 23),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xff0b1b45),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(color: Color(0xff52627e), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _Benefit(this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext c) => SizedBox(
    width: 230,
    child: Row(
      children: [
        Icon(icon, color: const Color(0xff155eef), size: 28),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xff0b1b45),
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 12, color: Color(0xff6b7890)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _AboutItem(this.icon, this.title, this.body);
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xff155eef)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xff0b1b45),
                ),
              ),
              Text(
                body,
                style: const TextStyle(color: Color(0xff52627e), height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactLine(this.icon, this.text);
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xff8fbcff)),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _ContactInfo extends StatelessWidget {
  const _ContactInfo();
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Talk to our team',
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 16),
      Text(
        'We respond quickly and help with rental, booking and account questions.',
        style: TextStyle(color: Color(0xffd7e5ff), height: 1.6),
      ),
      SizedBox(height: 30),
      _ContactLine(Icons.call_outlined, '+252 90 7 261305'),
      _ContactLine(Icons.mail_outline, 'gorgor@.so'),
      _ContactLine(Icons.location_on_outlined, 'Garowe, Somalia'),
      SizedBox(height: 12),
      Text(
        'Available for rental, bookings and account support.',
        style: TextStyle(color: Color(0xffd7e5ff), height: 1.5, fontSize: 13),
      ),
    ],
  );
}
