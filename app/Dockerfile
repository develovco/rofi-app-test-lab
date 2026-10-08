FROM node:18-alpine

RUN apk add --no-cache bash wget

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY . .

RUN chmod +x /app/entrypoint.sh /app/init-logs.sh

EXPOSE 3000

ENTRYPOINT ["/app/entrypoint.sh"]
