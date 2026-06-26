FROM nginx:alpine
RUN apk update && apk upgrade && rm /usr/share/nginx/html/index.html
COPY src/html/index.html /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
