// Backend DRF javoblari snake_case — bu yerda shu ko'rinishda o'qiladi
// (iOS'dagi `convertFromSnakeCase`ga mos vazifa, lekin Dart'da qo'lda).

class TokenPair {
  final String access;
  final String refresh;
  TokenPair({required this.access, required this.refresh});
  factory TokenPair.fromJson(Map<String, dynamic> j) =>
      TokenPair(access: j['access'], refresh: j['refresh']);
  Map<String, dynamic> toJson() => {'access': access, 'refresh': refresh};
}

class CompanyRef {
  final String id;
  final String slug;
  final String name;
  CompanyRef({required this.id, required this.slug, required this.name});
  factory CompanyRef.fromJson(Map<String, dynamic> j) =>
      CompanyRef(id: j['id'], slug: j['slug'], name: j['name']);
}

class AppUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? dateOfBirth;
  final String role;
  final String? workerId;
  final CompanyRef? company;
  final List<String> positions;
  final bool phoneVerified;
  final bool hasGoogle;
  final bool hasTelegram;

  AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.dateOfBirth,
    required this.role,
    this.workerId,
    this.company,
    this.positions = const [],
    this.phoneVerified = true,
    this.hasGoogle = false,
    this.hasTelegram = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    email: j['email'],
    firstName: j['first_name'],
    lastName: j['last_name'],
    phone: j['phone'],
    dateOfBirth: j['date_of_birth'],
    role: j['role'],
    workerId: j['worker_id'],
    company: j['company'] != null ? CompanyRef.fromJson(j['company']) : null,
    positions:
        (j['positions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    phoneVerified: j['phone_verified'] ?? true,
    hasGoogle: j['has_google'] ?? false,
    hasTelegram: j['has_telegram'] ?? false,
  );
}

class Variant {
  final String id;
  final String name;
  final String basePrice;
  final String width;
  final String height;
  final String depth;
  final String? colorHex;
  final String? textureUrl;
  // Odatda geometriya mahsulot darajasida bitta (Product.model3d) — har
  // rang uchun alohida model shart emas. Lekin ko'p materialli
  // mahsulotlarda firma ma'lum bir variant uchun alohida 3D fayl
  // yuklashi mumkin — shu holatda (`status == 'ready'`) Product.model3d
  // o'rniga shu ishlatiladi (qarang product_detail_screen.dart'dagi
  // `_activeModel3d`, web'dagi ProductDetail.jsx bilan bir xil naqsh).
  final Model3D? model3d;

  Variant({
    required this.id,
    required this.name,
    required this.basePrice,
    this.width = '1',
    this.height = '1',
    this.depth = '1',
    this.colorHex,
    this.textureUrl,
    this.model3d,
  });

  double get basePriceValue => double.tryParse(basePrice) ?? 0;
  double get widthValue => double.tryParse(width) ?? 1;
  double get heightValue => double.tryParse(height) ?? 1;
  double get depthValue => double.tryParse(depth) ?? 1;

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
    id: j['id'],
    name: j['name'],
    basePrice: j['base_price'].toString(),
    width: (j['width'] ?? 1).toString(),
    height: (j['height'] ?? 1).toString(),
    depth: (j['depth'] ?? 1).toString(),
    colorHex: j['color_hex'],
    textureUrl: j['texture_url'],
    model3d: j['model3d'] != null ? Model3D.fromJson(j['model3d']) : null,
  );
}

class ProductImage {
  final String id;
  final String? imageUrl;
  ProductImage({required this.id, this.imageUrl});
  factory ProductImage.fromJson(Map<String, dynamic> j) =>
      ProductImage(id: j['id'], imageUrl: j['image_url']);
}

class Model3D {
  final String? glbUrl;
  final String? usdzUrl;
  final String? status;
  Model3D({this.glbUrl, this.usdzUrl, this.status});
  factory Model3D.fromJson(Map<String, dynamic> j) =>
      Model3D(glbUrl: j['glb_url'], usdzUrl: j['usdz_url'], status: j['status']);
}

class CompanyTier {
  final String key;
  final String label;
  final String color;
  final int completedOrders;
  final double? rating;
  final int reviewCount;

  CompanyTier({
    required this.key,
    required this.label,
    required this.color,
    required this.completedOrders,
    this.rating,
    required this.reviewCount,
  });

  factory CompanyTier.fromJson(Map<String, dynamic> j) => CompanyTier(
    key: j['key'],
    label: j['label'],
    color: j['color'],
    completedOrders: j['completed_orders'] ?? 0,
    rating: (j['rating'] as num?)?.toDouble(),
    reviewCount: j['review_count'] ?? 0,
  );
}

class Company {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? address;
  final String? logoUrl;
  final CompanyTier? tier;
  final String? instagramUrl;
  final String? telegramUrl;
  final String? facebookUrl;
  final String? websiteUrl;
  final double? latitude;
  final double? longitude;

  Company({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.address,
    this.logoUrl,
    this.tier,
    this.instagramUrl,
    this.telegramUrl,
    this.facebookUrl,
    this.websiteUrl,
    this.latitude,
    this.longitude,
  });

  /// Google Maps'da shu nuqtani ochadigan havola — lat/lng bo'lmasa null.
  String? get mapUrl =>
      (latitude != null && longitude != null) ? 'https://www.google.com/maps?q=$latitude,$longitude' : null;

  /// Do'kon sahifasida bosiladigan ikonkalar ro'yxati — bo'sh havolalar
  /// chiqarib tashlanadi.
  Map<String, String> get socialLinks => {
    if (instagramUrl != null && instagramUrl!.isNotEmpty) 'Instagram': instagramUrl!,
    if (telegramUrl != null && telegramUrl!.isNotEmpty) 'Telegram': telegramUrl!,
    if (facebookUrl != null && facebookUrl!.isNotEmpty) 'Facebook': facebookUrl!,
    if (websiteUrl != null && websiteUrl!.isNotEmpty) 'Veb-sayt': websiteUrl!,
  };

  factory Company.fromJson(Map<String, dynamic> j) => Company(
    id: j['id'],
    name: j['name'],
    slug: j['slug'],
    description: j['description'],
    address: j['address'],
    logoUrl: j['logo_url'],
    tier: j['tier'] != null ? CompanyTier.fromJson(j['tier']) : null,
    instagramUrl: j['instagram_url'],
    telegramUrl: j['telegram_url'],
    facebookUrl: j['facebook_url'],
    latitude: double.tryParse(j['latitude']?.toString() ?? ''),
    longitude: double.tryParse(j['longitude']?.toString() ?? ''),
    websiteUrl: j['website_url'],
  );
}

class Review {
  final String id;
  final String? customerName;
  final int rating;
  final String? comment;
  final String createdAt;

  Review({
    required this.id,
    this.customerName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'],
    customerName: j['customer_name'],
    rating: j['rating'],
    comment: j['comment'],
    createdAt: j['created_at'] ?? '',
  );
}

class Product {
  final String id;
  final String company;
  final String companyName;
  final String? companySlug;
  final String? companyViloyat;
  final String? companyViloyatDisplay;
  final String? companyAddress;
  final String nameUz;
  final String? description;
  final String? imageUrl;
  final List<ProductImage> images;
  final bool isPublished;
  final String? colorTag;
  final List<Variant> variants;
  final Model3D? model3d;
  final bool isLiked;
  // Faqat "rasm bilan qidirish" natijalarida keladi (qarang search_service.dart).
  final double? similarityPercent;

  Product({
    required this.id,
    required this.company,
    required this.companyName,
    this.companySlug,
    this.companyViloyat,
    this.companyViloyatDisplay,
    this.companyAddress,
    required this.nameUz,
    this.description,
    this.imageUrl,
    this.images = const [],
    required this.isPublished,
    this.colorTag,
    this.variants = const [],
    this.model3d,
    this.isLiked = false,
    this.similarityPercent,
  });

  /// Kartochkada nomdan keyin ko'rsatiladigan qisqa xususiyat qatori —
  /// masalan "kulrang · 60×90×60 sm" (rang avtomatik aniqlangan, o'lcham
  /// birinchi variantdan, metrdan santimetrga o'tkazilib).
  String? get attributeSummary {
    final parts = <String>[];
    if (colorTag != null && colorTag!.isNotEmpty) parts.add(colorTag!);
    if (variants.isNotEmpty) {
      final v = variants.first;
      final w = (v.widthValue * 100).round();
      final h = (v.heightValue * 100).round();
      final d = (v.depthValue * 100).round();
      if (w > 1 && h > 1 && d > 1) parts.add('$w×$h×$d sm');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Galereya: bosh rasm + qo'shimcha rasmlar, birortasi bo'lmasa bo'sh.
  List<String> get galleryUrls => [
    if (imageUrl != null) imageUrl!,
    ...images.map((i) => i.imageUrl).whereType<String>(),
  ];

  /// Kartochka (Bosh sahifa/Katalog/Sevimlilar)da bitta rasm ko'rsatiladi —
  /// asosiy rasm bo'lmasa, galereyadagi birinchi rasm ishlatiladi.
  String? get cardImageUrl =>
      imageUrl ?? (images.isNotEmpty ? images.first.imageUrl : null);

  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    company: j['company'],
    companyName: j['company_name'] ?? '',
    companySlug: j['company_slug'],
    companyViloyat: j['company_viloyat'],
    companyViloyatDisplay: j['company_viloyat_display'],
    companyAddress: j['company_address'],
    nameUz: j['name_uz'] ?? '',
    description: j['description'],
    imageUrl: j['image_url'],
    images: (j['images'] as List? ?? [])
        .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
        .toList(),
    isPublished: j['is_published'] ?? false,
    colorTag: j['color_tag'],
    variants: (j['variants'] as List? ?? [])
        .map((e) => Variant.fromJson(e as Map<String, dynamic>))
        .toList(),
    model3d: j['model3d'] != null ? Model3D.fromJson(j['model3d']) : null,
    isLiked: j['is_liked'] ?? false,
    similarityPercent: (j['similarity_percent'] as num?)?.toDouble(),
  );
}

class Like {
  final String id;
  final String product;
  final Product productDetail;

  Like({required this.id, required this.product, required this.productDetail});

  factory Like.fromJson(Map<String, dynamic> j) => Like(
    id: j['id'],
    product: j['product'],
    productDetail: Product.fromJson(j['product_detail']),
  );
}

class OrderItemSummary {
  final String productName;
  final String variantName;
  final int quantity;
  final String subtotal;
  OrderItemSummary({
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.subtotal,
  });
  factory OrderItemSummary.fromJson(Map<String, dynamic> j) => OrderItemSummary(
    productName: j['product_name'] ?? '',
    variantName: j['variant_name'] ?? '',
    quantity: j['quantity'] ?? 1,
    subtotal: j['subtotal'].toString(),
  );
}

class WorkflowStepInstance {
  final String id;
  final String name;
  final String description;
  final String? stageDisplay;
  final String? roleDisplay;
  final String status;
  final String statusDisplay;
  final bool isAvailable;
  final String photoRequirement;
  // "Usta sahifasi" (`/workflow-instances/`dan to'g'ridan-to'g'ri kelganda) —
  // Order ichidagi nested holatda bular kerak emas, shuning uchun ixtiyoriy.
  final String? order;
  final String? orderDisplay;
  final String? orderStatus;
  final String? deadline;
  final bool isManual;

  WorkflowStepInstance({
    required this.id,
    required this.name,
    this.description = '',
    this.stageDisplay,
    this.roleDisplay,
    required this.status,
    required this.statusDisplay,
    required this.isAvailable,
    required this.photoRequirement,
    this.order,
    this.orderDisplay,
    this.orderStatus,
    this.deadline,
    this.isManual = false,
  });

  bool get isOverdue {
    if (deadline == null || status == 'completed') return false;
    final d = DateTime.tryParse(deadline!);
    return d != null && d.isBefore(DateTime.now());
  }

  factory WorkflowStepInstance.fromJson(Map<String, dynamic> j) =>
      WorkflowStepInstance(
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        stageDisplay: j['stage_display'],
        roleDisplay: j['role_display'],
        status: j['status'],
        statusDisplay: j['status_display'],
        isAvailable: j['is_available'] ?? false,
        photoRequirement: j['photo_requirement'] ?? 'optional',
        order: j['order'],
        orderDisplay: j['order_display'],
        orderStatus: j['order_status'],
        deadline: j['deadline'],
        isManual: j['is_manual'] ?? false,
      );
}

/// Xodimning oylik ish haqi hisob-kitobi — web'dagi `MyPayslips`
/// (FirmaPayroll.jsx) bilan bir xil maydonlar, faqat o'ziniki
/// (`GET /payslips/` xodim uchun avtomatik shu bilan cheklangan).
class Payslip {
  final String id;
  final String period;
  final String payType;
  final String payTypeDisplay;
  final String baseSalary;
  final int tasksCompleted;
  final String bonusPerTask;
  final String bonusAmount;
  final String commissionSales;
  final String commissionAmount;
  final String manualHours;
  final String hourlyAmount;
  final String workflowEarnings;
  final bool kpiMet;
  final String kpiBonusAmount;
  final String totalAmount;
  final bool isPaid;

  Payslip({
    required this.id,
    required this.period,
    required this.payType,
    required this.payTypeDisplay,
    required this.baseSalary,
    required this.tasksCompleted,
    required this.bonusPerTask,
    required this.bonusAmount,
    required this.commissionSales,
    required this.commissionAmount,
    required this.manualHours,
    required this.hourlyAmount,
    required this.workflowEarnings,
    required this.kpiMet,
    required this.kpiBonusAmount,
    required this.totalAmount,
    required this.isPaid,
  });

  factory Payslip.fromJson(Map<String, dynamic> j) => Payslip(
        id: j['id'],
        period: j['period'],
        payType: j['pay_type'] ?? '',
        payTypeDisplay: j['pay_type_display'] ?? '',
        baseSalary: j['base_salary']?.toString() ?? '0',
        tasksCompleted: j['tasks_completed'] ?? 0,
        bonusPerTask: j['bonus_per_task']?.toString() ?? '0',
        bonusAmount: j['bonus_amount']?.toString() ?? '0',
        commissionSales: j['commission_sales']?.toString() ?? '0',
        commissionAmount: j['commission_amount']?.toString() ?? '0',
        manualHours: j['manual_hours']?.toString() ?? '0',
        hourlyAmount: j['hourly_amount']?.toString() ?? '0',
        workflowEarnings: j['workflow_earnings']?.toString() ?? '0',
        kpiMet: j['kpi_met'] ?? false,
        kpiBonusAmount: j['kpi_bonus_amount']?.toString() ?? '0',
        totalAmount: j['total_amount']?.toString() ?? '0',
        isPaid: j['is_paid'] ?? false,
      );
}

class Order {
  final String id;
  final String companyName;
  final String status;
  final String statusDisplay;
  final String totalPrice;
  final String phone;
  final String address;
  final List<OrderItemSummary> items;
  final List<WorkflowStepInstance> workflowSteps;
  final int? progressPercent;

  Order({
    required this.id,
    required this.companyName,
    required this.status,
    required this.statusDisplay,
    required this.totalPrice,
    required this.phone,
    required this.address,
    this.items = const [],
    this.workflowSteps = const [],
    this.progressPercent,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'],
    companyName: j['company_name'] ?? '',
    status: j['status'] ?? '',
    statusDisplay: j['status_display'] ?? '',
    totalPrice: j['total_price'].toString(),
    phone: j['phone'] ?? '',
    address: j['address'] ?? '',
    items: (j['items'] as List? ?? [])
        .map((e) => OrderItemSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    workflowSteps: (j['workflow_steps'] as List? ?? [])
        .map((e) => WorkflowStepInstance.fromJson(e as Map<String, dynamic>))
        .toList(),
    progressPercent: j['progress_percent'],
  );
}

// kompaniya tomonidagi keyingi mumkin status o'tishlari (web orderStatus.js bilan bir xil)
const Map<String, List<String>> nextOrderStatus = {
  'new': ['accepted', 'cancelled'],
  'accepted': ['in_production', 'cancelled'],
  'in_production': ['ready'],
  'ready': ['delivering', 'completed'],
  'delivering': ['completed'],
};

const Map<String, String> orderStatusLabel = {
  'new': 'Kutilmoqda',
  'accepted': 'Qabul qilindi',
  'in_production': 'Ishlab chiqarilmoqda',
  'ready': 'Tayyor',
  'delivering': 'Yetkazilmoqda',
  'completed': 'Yakunlandi',
  'cancelled': 'Bekor qilindi',
};

class EmployeeInvitation {
  final String id;
  final String companyName;
  final List<String> positions;
  final String status;
  final String statusDisplay;

  EmployeeInvitation({
    required this.id,
    required this.companyName,
    required this.positions,
    required this.status,
    required this.statusDisplay,
  });

  factory EmployeeInvitation.fromJson(Map<String, dynamic> j) =>
      EmployeeInvitation(
        id: j['id'],
        companyName: j['company_name'] ?? '',
        positions: (j['positions'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        status: j['status'],
        statusDisplay: j['status_display'],
      );
}

class CareerEntry {
  final String companyName;
  final List<String> positions;
  final bool isActive;

  CareerEntry({
    required this.companyName,
    required this.positions,
    required this.isActive,
  });

  factory CareerEntry.fromJson(Map<String, dynamic> j) => CareerEntry(
    companyName: j['company_name'] ?? '',
    positions: (j['positions'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    isActive: j['is_active'] ?? false,
  );
}

class Paginated<T> {
  final int count;
  final List<T> results;
  Paginated({required this.count, required this.results});
  factory Paginated.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return Paginated(
      count: j['count'] ?? 0,
      results: (j['results'] as List? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Ilova-ichi xabarnoma — mijozga buyurtma holati, xodimga vazifa
/// tayinlash/tayyorlik xabarlari (qarang backend apps.notifications).
/// Dart'ning o'z `Notification` bazaviy klassi bilan chalkashmasligi
/// uchun `AppNotification` deb nomlangan.
class AppNotification {
  final String id;
  final String notifType;
  final String notifTypeDisplay;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.notifType,
    required this.notifTypeDisplay,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        notifType: j['notif_type'] ?? '',
        notifTypeDisplay: j['notif_type_display'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        isRead: j['is_read'] ?? false,
        createdAt: j['created_at'] ?? '',
      );
}

/// Ombor (xom ashyo yoki tayyor mahsulot) — faqat ko'rish uchun (mobil'da
/// hozircha faqat o'qish, boshqaruv veb-portalda).
class Warehouse {
  final String id;
  final String name;
  final String kind;
  final String kindDisplay;
  final String address;

  Warehouse({
    required this.id,
    required this.name,
    required this.kind,
    required this.kindDisplay,
    required this.address,
  });

  factory Warehouse.fromJson(Map<String, dynamic> j) => Warehouse(
        id: j['id'],
        name: j['name'],
        kind: j['kind'],
        kindDisplay: j['kind_display'] ?? '',
        address: j['address'] ?? '',
      );
}

class MaterialStock {
  final String id;
  final String materialName;
  final String materialUnit;
  final String quantity;
  final String materialUnitCost;

  MaterialStock({
    required this.id,
    required this.materialName,
    required this.materialUnit,
    required this.quantity,
    required this.materialUnitCost,
  });

  factory MaterialStock.fromJson(Map<String, dynamic> j) => MaterialStock(
        id: j['id'],
        materialName: j['material_name'] ?? '',
        materialUnit: j['material_unit'] ?? '',
        quantity: j['quantity']?.toString() ?? '0',
        materialUnitCost: j['material_unit_cost']?.toString() ?? '0',
      );
}

/// Qayta ishlatsa bo'ladigan bo'lak — `width` bo'lsa VARAQ (eni x bo'yi),
/// bo'lmasa CHIZIQLI (faqat uzunlik) qoldiq.
class MaterialRemnantItem {
  final String id;
  final String materialName;
  final String materialUnit;
  final String length;
  final String? width;
  final int quantity;

  MaterialRemnantItem({
    required this.id,
    required this.materialName,
    required this.materialUnit,
    required this.length,
    this.width,
    required this.quantity,
  });

  factory MaterialRemnantItem.fromJson(Map<String, dynamic> j) => MaterialRemnantItem(
        id: j['id'],
        materialName: j['material_name'] ?? '',
        materialUnit: j['material_unit'] ?? '',
        length: j['length']?.toString() ?? '0',
        width: j['width']?.toString(),
        quantity: j['quantity'] ?? 0,
      );
}

/// "1500000.00" -> "1 500 000"
String formatSom(String raw) {
  final value = double.tryParse(raw);
  if (value == null) return raw;
  final s = value.round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
