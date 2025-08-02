FROM node:18 AS build
WORKDIR /app
RUN apt-get update && \
    apt-get install -y python3 python3-dev build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY package*.json ./
RUN npm ci
COPY . .
ENV PUBLIC_URL=/
RUN npm run build

FROM nginx:stable-alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]



