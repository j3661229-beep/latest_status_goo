# ─────────────────────────────────────────────────────────────
# Status Go Backend — Production Dockerfile
# Optimized multi-stage build for Fastify + TypeScript + Prisma
# ─────────────────────────────────────────────────────────────

# Stage 1: Build TypeScript & Prisma Client
FROM node:20-alpine AS builder

WORKDIR /app

# Install system dependencies (openssl needed for Prisma on Alpine)
RUN apk add --no-cache openssl libc6-compat

# Install dependencies
COPY package*.json ./
COPY prisma ./prisma/
RUN npm install

# Copy source and config
COPY tsconfig*.json ./
COPY src ./src/

# Generate Prisma Client and compile TypeScript
RUN npx prisma generate
RUN npm run build

# Stage 2: Production runtime
FROM node:20-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

RUN apk add --no-cache openssl libc6-compat ffmpeg font-noto-devanagari fontconfig

ENV FFMPEG_PATH=ffmpeg
ENV FFPROBE_PATH=ffprobe
ENV CONTENT_FONT_NAME="Noto Sans Devanagari"

# Copy production dependencies & Prisma
COPY package*.json ./
COPY prisma ./prisma/
RUN npm install --omit=dev && npx prisma generate

# Copy compiled JavaScript output and static media assets
COPY --from=builder /app/dist ./dist
COPY assets ./assets/

# Non-root user for security
USER node

EXPOSE 3000

CMD ["node", "dist/server.js"]
