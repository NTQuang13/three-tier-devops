FROM node:18-alpine AS build
WORKDIR /src
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.27-alpine
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/build /usr/share/nginx/html
EXPOSE 80