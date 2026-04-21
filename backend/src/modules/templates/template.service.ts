// src/modules/templates/template.service.ts
import type { Redis } from 'ioredis';
import { PrismaClient, TemplateType, Language } from '@prisma/client';
import { TemplateRepository, TemplateFilterParams } from './template.repository';
import { CacheService } from '../../lib/cache/cache.service';
import { CK, TTL } from '../../lib/cache/keys';

export class TemplateService {
  private repo: TemplateRepository;
  private cache: CacheService;

  constructor(prisma: PrismaClient, redis: Redis) {
    this.repo = new TemplateRepository(prisma);
    this.cache = new CacheService(redis);
  }

  async list(params: TemplateFilterParams) {
    const lang = params.lang ?? 'ALL';
    const cat = params.categoryId ?? 'ALL';
    const type = params.type ?? 'ALL';
    const page = params.page ?? 1;

    const cacheKey = CK.templateList(lang, cat, type, page);
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const result = await this.repo.getByFilters(params);
    await this.cache.set(cacheKey, result, TTL.templateList);
    return result;
  }

  async getById(id: string) {
    const cacheKey = CK.templateById(id);
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const template = await this.repo.getById(id);
    if (template) {
      await this.cache.set(cacheKey, template, TTL.templateById);
    }
    return template;
  }

  async getFeatured() {
    const cached = await this.cache.get(CK.featured);
    if (cached) return cached;

    const data = await this.repo.getFeatured();
    await this.cache.set(CK.featured, data, TTL.featured);
    return data;
  }

  async getTrending() {
    const cached = await this.cache.get(CK.trending);
    if (cached) return cached;

    const data = await this.repo.getTrending();
    await this.cache.set(CK.trending, data, TTL.trending);
    return data;
  }

  async getNew(type?: TemplateType, lang?: Language, page = 1) {
    const cacheKey = `${CK.newArrivals}:${type ?? 'ALL'}:${lang ?? 'ALL'}:${page}`;
    const cached = await this.cache.get(cacheKey);
    if (cached) return cached;

    const data = await this.repo.getNew(type, lang, page);
    await this.cache.set(cacheKey, data, TTL.newArrivals);
    return data;
  }

  async invalidateAllCaches() {
    await this.cache.invalidateTemplateCache();
  }
}
