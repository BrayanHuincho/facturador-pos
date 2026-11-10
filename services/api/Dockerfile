FROM node:24-bookworm-slim AS compilacion
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:24-bookworm-slim AS dependencias
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:24-bookworm-slim
ENV NODE_ENV=production \
    TZ=America/Lima
WORKDIR /app
COPY package.json ./
COPY --from=dependencias /app/node_modules ./node_modules
COPY --from=compilacion /app/dist ./dist
USER node
EXPOSE 4200
CMD ["node", "dist/server.js"]
