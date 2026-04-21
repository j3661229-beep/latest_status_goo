// src/modules/templates/template.repository.ts
import { PrismaClient, TemplateStatus, TemplateType, Language } from '@prisma/client';

export interface TemplateFilterParams {
  lang?: Language;
  categoryId?: string;
  type?: TemplateType;
  page?: number;
  limit?: number;
  isPremium?: boolean;
  isFeatured?: boolean;
  isTrending?: boolean;
}

export class TemplateRepository {
  constructor(private prisma: PrismaClient) {}

  async getByFilters(params: TemplateFilterParams) {
    const page = params.page ?? 1;
    const limit = Math.min(params.limit ?? 20, 50);
    const skip = (page - 1) * limit;

    const where: any = {
      status: TemplateStatus.APPROVED,
    };

    if (params.type) where.type = params.type;
    if (params.categoryId) where.categoryId = params.categoryId;
    if (params.lang) where.primaryLanguage = params.lang;
    if (params.isPremium !== undefined) where.isPremium = params.isPremium;
    if (params.isFeatured) where.isFeatured = true;
    if (params.isTrending) where.isTrending = true;

    const [data, total] = await Promise.all([
      this.prisma.template.findMany({
        where,
        include: { category: true },
        orderBy: [
          { isFeatured: 'desc' },
          { sortOrder: 'asc' },
          { useCount: 'desc' },
          { createdAt: 'desc' },
        ],
        skip,
        take: limit,
      }),
      this.prisma.template.count({ where }),
    ]);

    return { data, total, page, limit, hasMore: skip + data.length < total };
  }

  async getById(id: string) {
    return this.prisma.template.findUnique({
      where: { id },
      include: { category: true, creator: { select: { id: true, name: true } } },
    });
  }

  async getFeatured() {
    return this.prisma.template.findMany({
      where: { status: TemplateStatus.APPROVED, isFeatured: true },
      include: { category: true },
      orderBy: { sortOrder: 'asc' },
      take: 5,
    });
  }

  async getTrending() {
    return this.prisma.template.findMany({
      where: { status: TemplateStatus.APPROVED },
      include: { category: true },
      orderBy: [{ shareCount: 'desc' }, { useCount: 'desc' }],
      take: 20,
    });
  }

  async getNew(type?: TemplateType, lang?: Language, page = 1) {
    const limit = 20;
    const skip = (page - 1) * limit;
    const where: any = { status: TemplateStatus.APPROVED, isNew: true };
    if (type) where.type = type;
    if (lang) where.primaryLanguage = lang;

    const [data, total] = await Promise.all([
      this.prisma.template.findMany({
        where,
        include: { category: true },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.template.count({ where }),
    ]);

    return { data, total, page, limit, hasMore: skip + data.length < total };
  }

  async incrementCounter(templateId: string, field: 'useCount' | 'shareCount' | 'viewCount' | 'downloadCount') {
    return this.prisma.template.update({
      where: { id: templateId },
      data: { [field]: { increment: 1 } },
    });
  }
}
