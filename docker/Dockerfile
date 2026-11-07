# Build stage: compile the Vite/React SPA
FROM node:20-alpine AS builder
WORKDIR /app
COPY app/package*.json ./
RUN npm ci
COPY app/ ./
RUN npm run build

# Serve stage: static nginx with SPA fallback
FROM nginx:1.27-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
