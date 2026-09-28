import { Injectable, NotFoundException } from '@nestjs/common';
import { UserApprovalStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ClausesService } from '../clauses/clauses.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clausesService: ClausesService,
  ) {}

  // Only APPROVED users are listed as managers. PENDING and REJECTED accounts can still log in
  // (see `approve()`).
  async findAll(excludeUserId?: string) {
    const users = await this.prisma.user.findMany({
      where: {
        status: UserApprovalStatus.APPROVED,
        ...(excludeUserId ? { id: { not: excludeUserId } } : {}),
      },
      orderBy: { name: 'asc' },
    });

    return Promise.all(
      users.map(async (u) => ({
        ...this.toPublicUser(u),
        stats: await this.clausesService.getStatsForUser(u.id),
      })),
    );
  }

  // Admin-only (AdminGuard on the route): accounts awaiting review, oldest first.
  async findPending() {
    const users = await this.prisma.user.findMany({
      where: { status: UserApprovalStatus.PENDING },
      orderBy: { createdAt: 'asc' },
    });
    return users.map((u) => this.toPublicUser(u));
  }

  async approve(id: string) {
    return this.setStatus(id, UserApprovalStatus.APPROVED);
  }

  async reject(id: string) {
    return this.setStatus(id, UserApprovalStatus.REJECTED);
  }

  private async setStatus(id: string, status: UserApprovalStatus) {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }
    const updated = await this.prisma.user.update({ where: { id }, data: { status } });
    return this.toPublicUser(updated);
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
