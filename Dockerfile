FROM node:17-alpine

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci

COPY build/ ./build/
COPY views/ ./views/

COPY config/config.yml.example ./config/config.yml.example
EXPOSE 80
CMD ["node", "build/index.js"]