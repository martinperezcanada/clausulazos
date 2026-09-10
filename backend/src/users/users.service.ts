import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ClausesService } from '../clauses/clauses.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clausesService: ClausesService,
  ) {}

  async findAll(excludeUserId?: string) {
    const users = await this.prisma.user.findMany({
      where: excludeUserId ? { id: { not: excludeUserId } } : undefined,
      orderBy: { name: 'asc' },
    });

    return Promise.all(
      users.map(async (u) => ({
        ...this.toPublicUser(u),
        stats: await this.clausesService.getStatsForUser(u.id),
      })),
    );
  }

  async findOne(id: string) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }
    return {
      ...this.toPublicUser(user),
      stats: await this.clausesService.getStatsForUser(user.id),
    };
  }

  async getStats(userId: string) {
    return this.clausesService.getStatsForUser(userId);
  }

  private toPublicUser(user: { id: string; name: string; email: string; createdAt: Date }) {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      createdAt: user.createdAt,
    };
  }
}
