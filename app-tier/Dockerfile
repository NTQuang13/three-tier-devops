FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .
EXPOSE 4000
USER node
CMD ["node", "index.js"]