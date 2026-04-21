// prisma/seed.ts
import { PrismaClient, Language, Plan, UserRole, TemplateType, TemplateStatus } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting Status Go database seed...\n');

  // ── 1. CATEGORIES ─────────────────────────────────────────
  console.log('📂 Seeding categories...');
  const categories = await Promise.all([
    prisma.category.upsert({
      where: { slug: 'devotional' },
      update: {},
      create: {
        slug: 'devotional',
        nameEn: 'Devotional',
        nameHi: 'भक्ति',
        nameMr: 'भक्ती',
        emoji: '🙏',
        gradient: 'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
        sortOrder: 1,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'motivational' },
      update: {},
      create: {
        slug: 'motivational',
        nameEn: 'Motivational',
        nameHi: 'प्रेरणा',
        nameMr: 'प्रेरणा',
        emoji: '💪',
        gradient: 'linear-gradient(135deg, #7C5CFC 0%, #FF6B9D 100%)',
        sortOrder: 2,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'good-morning' },
      update: {},
      create: {
        slug: 'good-morning',
        nameEn: 'Good Morning',
        nameHi: 'सुप्रभात',
        nameMr: 'शुभ सकाळ',
        emoji: '🌅',
        gradient: 'linear-gradient(135deg, #2DD4BF 0%, #7C5CFC 100%)',
        sortOrder: 3,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'festival' },
      update: {},
      create: {
        slug: 'festival',
        nameEn: 'Festival',
        nameHi: 'त्योहार',
        nameMr: 'सण',
        emoji: '🎉',
        gradient: 'linear-gradient(135deg, #FF6B9D 0%, #FFB347 100%)',
        sortOrder: 4,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'birthday' },
      update: {},
      create: {
        slug: 'birthday',
        nameEn: 'Birthday',
        nameHi: 'जन्मदिन',
        nameMr: 'वाढदिवस',
        emoji: '🎂',
        gradient: 'linear-gradient(135deg, #7C5CFC 0%, #FF6B9D 100%)',
        sortOrder: 5,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'nature' },
      update: {},
      create: {
        slug: 'nature',
        nameEn: 'Nature',
        nameHi: 'प्रकृति',
        nameMr: 'निसर्ग',
        emoji: '🌿',
        gradient: 'linear-gradient(135deg, #10B981 0%, #2DD4BF 100%)',
        sortOrder: 6,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'love' },
      update: {},
      create: {
        slug: 'love',
        nameEn: 'Love & Relationship',
        nameHi: 'प्यार',
        nameMr: 'प्रेम',
        emoji: '❤️',
        gradient: 'linear-gradient(135deg, #FF6B9D 0%, #FF8E53 100%)',
        sortOrder: 7,
      },
    }),
    prisma.category.upsert({
      where: { slug: 'good-night' },
      update: {},
      create: {
        slug: 'good-night',
        nameEn: 'Good Night',
        nameHi: 'शुभ रात्रि',
        nameMr: 'शुभ रात्री',
        emoji: '🌙',
        gradient: 'linear-gradient(135deg, #1a1a2e 0%, #7C5CFC 100%)',
        sortOrder: 8,
      },
    }),
  ]);
  console.log(`   ✅ ${categories.length} categories created\n`);

  // ── 2. ADMIN + CREATOR USERS ───────────────────────────────
  console.log('👥 Seeding users...');
  
  const defaultPassword = await bcrypt.hash('admin123', 10);

  const superAdmin = await prisma.user.upsert({
    where: { email: 'superadmin@statusgo.app' },
    update: { password: defaultPassword },
    create: {
      email: 'superadmin@statusgo.app',
      name: 'Super Admin',
      password: defaultPassword,
      displayName: 'Super Admin',
      role: UserRole.SUPER_ADMIN,
      plan: Plan.PREMIUM,
      language: Language.HINDI,
      isActive: true,
    },
  });

  const manager = await prisma.user.upsert({
    where: { email: 'manager@statusgo.app' },
    update: { password: defaultPassword },
    create: {
      email: 'manager@statusgo.app',
      password: defaultPassword,
      name: 'Content Manager',
      displayName: 'Content Manager',
      role: UserRole.MANAGER,
      plan: Plan.PREMIUM,
      language: Language.HINDI,
      isActive: true,
    },
  });

  const creator1 = await prisma.user.upsert({
    where: { email: 'creator1@statusgo.app' },
    update: {},
    create: {
      email: 'creator1@statusgo.app',
      name: 'Rahul Sharma',
      displayName: 'Rahul S.',
      role: UserRole.CREATOR,
      plan: Plan.FREE,
      language: Language.HINDI,
      isActive: true,
    },
  });

  const creator2 = await prisma.user.upsert({
    where: { email: 'creator2@statusgo.app' },
    update: {},
    create: {
      email: 'creator2@statusgo.app',
      name: 'Priya Kulkarni',
      displayName: 'Priya K.',
      role: UserRole.CREATOR,
      plan: Plan.FREE,
      language: Language.MARATHI,
      isActive: true,
    },
  });

  const testUser = await prisma.user.upsert({
    where: { email: 'user@statusgo.app' },
    update: {},
    create: {
      email: 'user@statusgo.app',
      name: 'Ramesh Gupta',
      displayName: 'Ramesh Ji',
      role: UserRole.USER,
      plan: Plan.FREE,
      language: Language.HINDI,
      isActive: true,
      streakCount: 5,
    },
  });

  // Creator profiles
  await prisma.creatorProfile.upsert({
    where: { userId: creator1.id },
    update: {},
    create: {
      userId: creator1.id,
      displayName: 'Rahul S.',
      bio: 'Creating devotional and motivational content for Hindi users.',
      specialization: ['devotional', 'motivational'],
      approvedCount: 12,
      rejectedCount: 2,
      pendingCount: 1,
      totalUploads: 15,
      approvalRate: 85.7,
      isVerified: true,
      verifiedAt: new Date(),
    },
  });

  await prisma.creatorProfile.upsert({
    where: { userId: creator2.id },
    update: {},
    create: {
      userId: creator2.id,
      displayName: 'Priya K.',
      bio: 'Marathi festival and good morning content specialist.',
      specialization: ['festival', 'good-morning'],
      approvedCount: 8,
      rejectedCount: 3,
      pendingCount: 2,
      totalUploads: 13,
      approvalRate: 72.7,
      isVerified: false,
    },
  });
  console.log('   ✅ 5 users + 2 creator profiles created\n');

  // ── 3. TEMPLATES ───────────────────────────────────────────
  console.log('🖼  Seeding templates...');
  const devotionalCat = categories.find(c => c.slug === 'devotional')!;
  const motivationalCat = categories.find(c => c.slug === 'motivational')!;
  const morningCat = categories.find(c => c.slug === 'good-morning')!;
  const festivalCat = categories.find(c => c.slug === 'festival')!;
  const birthdayCat = categories.find(c => c.slug === 'birthday')!;
  const goodNightCat = categories.find(c => c.slug === 'good-night')!;

  const templateSeed = [
    // ── DEVOTIONAL ──────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: devotionalCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'जय श्री राम',
      nameMr: 'जय श्री राम',
      nameEn: 'Jai Shri Ram',
      quoteHi: '🙏 राम नाम सत्य है, बाकी सब झूठ है। जय श्री राम!',
      quoteMr: '🙏 राम नाम सत्य आहे, बाकी सब असत्य आहे। जय श्री राम!',
      quoteEn: '🙏 The name of Ram is truth, everything else is false. Jai Shri Ram!',
      gradient: 'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
      tags: ['ram', 'devotional', 'hindi', 'jai-shri-ram'],
      isFeatured: true,
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: true,
      photoZoneX: 0.5,
      photoZoneY: 0.25,
      photoZoneSize: 0.2,
      photoZoneShape: 'circle',
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.55,
      useCount: 4521,
      shareCount: 3102,
      viewCount: 12000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: devotionalCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'गणेश वंदना',
      nameMr: 'गणेश वंदना',
      nameEn: 'Ganesh Vandana',
      quoteHi: '🐘 वक्रतुण्ड महाकाय सूर्यकोटि समप्रभ। निर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा।।',
      quoteMr: '🐘 वक्रतुंड महाकाय सूर्यकोटि समप्रभ। निर्विघ्नं कुरु मे देव सर्वकार्येषु सर्वदा।।',
      quoteEn: '🐘 O Lord Ganesha with curved trunk and mighty form, shining like the brilliance of a million suns. Bless me always, removing all obstacles in my work.',
      gradient: 'linear-gradient(135deg, #FF8C00 0%, #FFD700 100%)',
      tags: ['ganesh', 'devotional', 'marathi', 'vandana', 'hindi'],
      isFeatured: false,
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: false,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.75,
      useCount: 3876,
      shareCount: 2654,
      viewCount: 9800,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: devotionalCat.id,
      creatorId: creator2.id,
      reviewerId: manager.id,
      nameHi: 'हनुमान चालीसा',
      nameMr: 'हनुमान चालीसा',
      nameEn: 'Hanuman Chalisa',
      quoteHi: '🚩 मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम्।',
      quoteMr: '🚩 मनोजवं मारुततुल्यवेगं जितेन्द्रियं बुद्धिमतां वरिष्ठम्।',
      quoteEn: '🚩 Swift as the mind and equal to the wind god, with all senses subdued, he is foremost among the intelligent.',
      gradient: 'linear-gradient(135deg, #FF4500 0%, #FF6B35 100%)',
      tags: ['hanuman', 'chalisa', 'devotional', 'hindi'],
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: true,
      photoZoneX: 0.5,
      photoZoneY: 0.3,
      photoZoneSize: 0.18,
      photoZoneShape: 'circle',
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.62,
      useCount: 2943,
      shareCount: 1987,
      viewCount: 7600,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── MOTIVATIONAL ─────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: motivationalCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'सफलता की राह',
      nameMr: 'यशाची वाट',
      nameEn: 'Path to Success',
      quoteHi: '💪 हर कठिनाई एक अवसर है, बस नज़रिया बदलो और आगे बढ़ो।',
      quoteMr: '💪 प्रत्येक अडचण ही एक संधी आहे, फक्त दृष्टिकोन बदला आणि पुढे जा।',
      quoteEn: '💪 Every difficulty is an opportunity, just change your perspective and move forward.',
      gradient: 'linear-gradient(135deg, #7C5CFC 0%, #FF6B9D 100%)',
      tags: ['motivation', 'success', 'hindi', 'inspiration'],
      isFeatured: true,
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.8,
      useCount: 5234,
      shareCount: 4102,
      viewCount: 15000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: motivationalCat.id,
      creatorId: creator2.id,
      reviewerId: manager.id,
      nameHi: 'सोमवार प्रेरणा',
      nameMr: 'सोमवार प्रेरणा',
      nameEn: 'Monday Motivation',
      quoteHi: '🌟 नई शुरुआत, नई उम्मीद। आज का दिन तुम्हारा है, बस विश्वास रखो।',
      quoteMr: '🌟 नवी सुरुवात, नवी आशा। आजचा दिवस तुमचा आहे, फक्त विश्वास ठेवा।',
      quoteEn: '🌟 New beginning, new hope. Today is your day, just believe in yourself.',
      gradient: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      tags: ['monday', 'motivation', 'hindi', 'marathi', 'morning'],
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.82,
      isTrending: true,
      useCount: 3210,
      shareCount: 2543,
      viewCount: 8900,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── GOOD MORNING ─────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: morningCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'सुप्रभात',
      nameMr: 'शुभ सकाळ',
      nameEn: 'Good Morning',
      quoteHi: '🌅 हर सुबह एक नया मौका है। उठो, मुस्कुराओ और दुनिया को अपनाओ।',
      quoteMr: '🌅 प्रत्येक सकाळ एक नवी संधी आहे. उठा, हसा आणि जगाला आलिंगन द्या.',
      quoteEn: '🌅 Every morning is a new chance. Wake up, smile and embrace the world.',
      gradient: 'linear-gradient(135deg, #2DD4BF 0%, #7C5CFC 100%)',
      tags: ['good-morning', 'subprabhat', 'hindi', 'marathi'],
      isFeatured: true,
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: true,
      photoZoneX: 0.5,
      photoZoneY: 0.28,
      photoZoneSize: 0.22,
      photoZoneShape: 'circle',
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.6,
      useCount: 8932,
      shareCount: 7234,
      viewCount: 25000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: morningCat.id,
      creatorId: creator2.id,
      reviewerId: manager.id,
      nameHi: 'शुभ प्रभात - फूल',
      nameMr: 'शुभ सकाळ - फुले',
      nameEn: 'Good Morning - Flowers',
      quoteHi: '🌸 सुबह की ताज़ी हवा, खिलते फूलों की महक। शुभ प्रभात!',
      quoteMr: '🌸 सकाळच्या ताज्या हवेचा, फुलांचा सुगंध. शुभ सकाळ!',
      quoteEn: '🌸 Fresh morning breeze, fragrance of blooming flowers. Good Morning!',
      gradient: 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)',
      tags: ['good-morning', 'flowers', 'hindi', 'marathi', 'nature'],
      primaryLanguage: Language.MARATHI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.78,
      useCount: 4123,
      shareCount: 3456,
      viewCount: 11000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── FESTIVAL ──────────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: festivalCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'दीपावली शुभकामनाएं',
      nameMr: 'दीपावली शुभेच्छा',
      nameEn: 'Happy Diwali',
      quoteHi: '🪔 दीपावली की हार्दिक शुभकामनाएं! प्रकाश हो, खुशियां हो, हर पल उत्सव हो।',
      quoteMr: '🪔 दीपावलीच्या हार्दिक शुभेच्छा! प्रकाश असो, आनंद असो, प्रत्येक क्षण उत्सव असो.',
      quoteEn: '🪔 Happy Diwali! May there be light, joy, and celebration in every moment.',
      gradient: 'linear-gradient(135deg, #FF6B9D 0%, #FFB347 100%)',
      tags: ['diwali', 'festival', 'hindi', 'marathi', 'deepawali'],
      isFeatured: true,
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: true,
      photoZoneX: 0.5,
      photoZoneY: 0.25,
      photoZoneSize: 0.2,
      photoZoneShape: 'circle',
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.58,
      useCount: 12453,
      shareCount: 9876,
      viewCount: 35000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: festivalCat.id,
      creatorId: creator2.id,
      reviewerId: manager.id,
      nameHi: 'होली मुबारक',
      nameMr: 'होळी शुभेच्छा',
      nameEn: 'Happy Holi',
      quoteHi: '🎨 रंगों का त्योहार! होली मुबारक हो, जीवन में खुशियों के रंग भरे रहें।',
      quoteMr: '🎨 रंगांचा सण! होळीच्या शुभेच्छा, आयुष्यात आनंदाचे रंग भरले राहोत.',
      quoteEn: '🎨 Festival of colors! Happy Holi, may your life be filled with colors of joy.',
      gradient: 'linear-gradient(135deg, #f857a6 0%, #ff5858 0%, #f7971e 100%)',
      tags: ['holi', 'festival', 'hindi', 'marathi', 'colors'],
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.8,
      useCount: 6543,
      shareCount: 5432,
      viewCount: 18000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── BIRTHDAY ──────────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: birthdayCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'जन्मदिन मुबारक',
      nameMr: 'वाढदिवसाच्या शुभेच्छा',
      nameEn: 'Happy Birthday',
      quoteHi: '🎂 जन्मदिन मुबारक! भगवान आपको सदा खुश रखे और सभी मनोकामनाएं पूरी करे।',
      quoteMr: '🎂 वाढदिवसाच्या हार्दिक शुभेच्छा! देव तुम्हाला सदा आनंदी ठेवो आणि सर्व इच्छा पूर्ण करो.',
      quoteEn: '🎂 Happy Birthday! May God always keep you happy and fulfill all your wishes.',
      gradient: 'linear-gradient(135deg, #7C5CFC 0%, #FF6B9D 100%)',
      tags: ['birthday', 'janamdin', 'hindi', 'marathi', 'wishes'],
      isFeatured: false,
      primaryLanguage: Language.HINDI,
      photoZoneEnabled: true,
      photoZoneX: 0.5,
      photoZoneY: 0.22,
      photoZoneSize: 0.25,
      photoZoneShape: 'circle',
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.55,
      useCount: 7890,
      shareCount: 6234,
      viewCount: 22000,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── PENDING (for review queue demo) ───────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.PENDING,
      categoryId: devotionalCat.id,
      creatorId: creator2.id,
      nameHi: 'शिव भक्ति',
      nameMr: 'शिव भक्ती',
      nameEn: 'Shiva Devotion',
      quoteHi: '🕉️ हर हर महादेव! शिव की कृपा से जीवन में सुख, शांति और समृद्धि आए।',
      quoteMr: '🕉️ हर हर महादेव! शिवाच्या कृपेने आयुष्यात सुख, शांती आणि समृद्धी येवो.',
      quoteEn: '🕉️ Har Har Mahadev! May the blessings of Shiva bring happiness, peace and prosperity.',
      gradient: 'linear-gradient(135deg, #4776E6 0%, #8E54E9 100%)',
      tags: ['shiva', 'mahadev', 'devotional', 'hindi', 'marathi'],
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.78,
      submittedAt: new Date(),
    },
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.PENDING,
      categoryId: morningCat.id,
      creatorId: creator1.id,
      nameHi: 'नई सुबह नई शुरुआत',
      nameMr: 'नवी सकाळ नवी सुरुवात',
      nameEn: 'New Morning New Beginning',
      quoteHi: '☀️ हर सुबह एक नया पन्ना है, इसे सुंदर बनाओ।',
      quoteMr: '☀️ प्रत्येक सकाळ एक नवे पान आहे, ते सुंदर बनवा.',
      quoteEn: '☀️ Every morning is a new page, make it beautiful.',
      gradient: 'linear-gradient(135deg, #FDDB92 0%, #D1FDFF 100%)',
      tags: ['good-morning', 'hindi', 'marathi', 'new-beginning'],
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.8,
      submittedAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
    },
    // ── GOOD NIGHT ────────────────────────────────
    {
      type: TemplateType.IMAGE,
      status: TemplateStatus.APPROVED,
      categoryId: goodNightCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'शुभ रात्रि',
      nameMr: 'शुभ रात्री',
      nameEn: 'Good Night',
      quoteHi: '🌙 रात को सो जाओ सपनों के साथ, सुबह उठो इरादों के साथ। शुभ रात्रि!',
      quoteMr: '🌙 रात्री स्वप्नांसोबत झोपा, सकाळी इराद्यांसोबत उठा. शुभ रात्री!',
      quoteEn: '🌙 Sleep at night with dreams, wake up in the morning with intentions. Good Night!',
      gradient: 'linear-gradient(135deg, #1a1a2e 0%, #7C5CFC 100%)',
      tags: ['good-night', 'shubhratri', 'hindi', 'marathi'],
      primaryLanguage: Language.HINDI,
      nameZoneEnabled: true,
      nameZoneX: 0.5,
      nameZoneY: 0.8,
      useCount: 3456,
      shareCount: 2789,
      viewCount: 9800,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
    // ── VIDEO TEMPLATE ────────────────────────────
    {
      type: TemplateType.VIDEO,
      status: TemplateStatus.APPROVED,
      categoryId: devotionalCat.id,
      creatorId: creator1.id,
      reviewerId: superAdmin.id,
      nameHi: 'जय गणेश - वीडियो स्टेटस',
      nameMr: 'जय गणेश - व्हिडिओ स्टेटस',
      nameEn: 'Jai Ganesh - Video Status',
      quoteHi: '🎬 गणपति बप्पा मोरया! यह वीडियो स्टेटस आपके WhatsApp के लिए।',
      quoteMr: '🎬 गणपती बाप्पा मोरया! हे व्हिडिओ स्टेटस तुमच्या WhatsApp साठी.',
      quoteEn: '🎬 Ganpati Bappa Morya! This video status is for your WhatsApp.',
      gradient: 'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
      videoUrl: 'https://example.com/videos/ganesh-status.m3u8',
      videoThumbUrl: 'https://placehold.co/400x700/F7971E/white?text=Ganesh+Video',
      videoDuration: 30,
      tags: ['ganesh', 'video', 'devotional', 'hindi', 'marathi', 'whatsapp-status'],
      primaryLanguage: Language.HINDI,
      isPremium: false,
      useCount: 2341,
      shareCount: 1876,
      viewCount: 6700,
      reviewedAt: new Date(),
      submittedAt: new Date(),
    },
  ];

  let templateCount = 0;
  for (const tpl of templateSeed) {
    await prisma.template.create({ data: tpl });
    templateCount++;
  }
  console.log(`   ✅ ${templateCount} templates created\n`);

  // ── 4. FESTIVALS ───────────────────────────────
  console.log('🎉 Seeding festivals...');

  const year = new Date().getFullYear();
  const festivals = [
    { nameHi: 'दीपावली', nameMr: 'दीपावली', nameEn: 'Diwali', emoji: '🪔', month: 10, day: 29 },
    { nameHi: 'होली', nameMr: 'होळी', nameEn: 'Holi', emoji: '🎨', month: 3, day: 14 },
    { nameHi: 'रक्षाबंधन', nameMr: 'रक्षाबंधन', nameEn: 'Raksha Bandhan', emoji: '🤝', month: 8, day: 9 },
    { nameHi: 'नवरात्रि', nameMr: 'नवरात्री', nameEn: 'Navratri', emoji: '🌺', month: 10, day: 3 },
    { nameHi: 'गणेश चतुर्थी', nameMr: 'गणेश चतुर्थी', nameEn: 'Ganesh Chaturthi', emoji: '🐘', month: 8, day: 27 },
    { nameHi: 'ईद उल फ़ित्र', nameMr: 'ईद उल फित्र', nameEn: 'Eid ul Fitr', emoji: '☪️', month: 4, day: 1 },
    { nameHi: 'क्रिसमस', nameMr: 'ख्रिसमस', nameEn: 'Christmas', emoji: '🎄', month: 12, day: 25 },
    { nameHi: 'नव वर्ष', nameMr: 'नवीन वर्ष', nameEn: 'New Year', emoji: '🎆', month: 1, day: 1 },
    { nameHi: 'मकर संक्रांति', nameMr: 'मकर संक्रांत', nameEn: 'Makar Sankranti', emoji: '🪁', month: 1, day: 14 },
    { nameHi: 'बसंत पंचमी', nameMr: 'वसंत पंचमी', nameEn: 'Basant Panchami', emoji: '🌼', month: 2, day: 3 },
  ];

  let festivalCount = 0;
  for (const f of festivals) {
    await prisma.festival.create({
      data: {
        nameHi: f.nameHi,
        nameMr: f.nameMr,
        nameEn: f.nameEn,
        emoji: f.emoji,
        date: new Date(year, f.month - 1, f.day),
        isRecurring: true,
        notifyDaysBefore: 2,
        isActive: true,
        categoryId: festivalCat.id,
        sortOrder: festivalCount,
      },
    });
    festivalCount++;
  }
  console.log(`   ✅ ${festivalCount} festivals created\n`);

  // ── 5. APP CONFIG ──────────────────────────────
  console.log('⚙️  Seeding app config...');
  const configs = [
    { key: 'app_version_android', value: '1.0.0', type: 'string', description: 'Minimum Android app version required' },
    { key: 'maintenance_mode', value: 'false', type: 'boolean', description: 'Put app in maintenance mode' },
    { key: 'daily_free_limit_images', value: '10', type: 'number', description: 'Free user daily image download limit' },
    { key: 'daily_free_limit_videos', value: '3', type: 'number', description: 'Free user daily video download limit' },
    { key: 'featured_template_count', value: '5', type: 'number', description: 'Number of featured templates on home' },
    { key: 'trending_template_count', value: '20', type: 'number', description: 'Number of trending templates shown' },
    { key: 'premium_price_monthly', value: '9900', type: 'number', description: 'Premium monthly price in paise (₹99)' },
    { key: 'premium_price_annual', value: '79900', type: 'number', description: 'Premium annual price in paise (₹799)' },
  ];

  for (const config of configs) {
    await prisma.appConfig.upsert({
      where: { key: config.key },
      update: {},
      create: { key: config.key, value: config.value, type: config.type, description: config.description, updatedBy: superAdmin.id },
    });
  }
  console.log(`   ✅ ${configs.length} app config entries created\n`);

  console.log('✨ Database seeded successfully!\n');
  console.log('📊 Summary:');
  console.log(`   Categories : ${categories.length}`);
  console.log(`   Templates  : ${templateCount} (${templateCount - 2} approved, 2 pending)`);
  console.log(`   Festivals  : ${festivalCount}`);
  console.log(`   Users      : 5 (1 super admin, 1 manager, 2 creators, 1 test user)`);
  console.log(`   App Config : ${configs.length} entries`);
  console.log('\n🔑 Test Credentials:');
  console.log('   Super Admin: superadmin@statusgo.app');
  console.log('   Manager:     manager@statusgo.app');
  console.log('   Creator 1:   creator1@statusgo.app');
  console.log('   Creator 2:   creator2@statusgo.app');
  console.log('   Test User:   user@statusgo.app');
}

main()
  .catch(e => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
