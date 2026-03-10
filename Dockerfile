# Stage 1: build and test
FROM node:20-alpine AS build

WORKDIR /usr/src/app

ENV NODE_ENV=development

COPY package.json package-lock.json* ./
RUN npm install --no-fund --no-audit

COPY . .

RUN npm test

# Stage 2: production image
FROM node:20-alpine AS production

WORKDIR /usr/src/app

ENV NODE_ENV=production

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY package.json package-lock.json* ./
RUN npm install --only=production --no-fund --no-audit

COPY --from=build /usr/src/app/src ./src

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.js"]
