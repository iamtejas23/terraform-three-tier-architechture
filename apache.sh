#! /bin/bash
# Use an official Node.js image to build the React app
FROM node:18 AS build

# Set the working directory
WORKDIR /app

# Install git
RUN apt-get update && apt-get install -y git

# Clone the GitHub repository (replace with your repo URL)
RUN git clone https://github.com/iamtejas23/personal-portfolio.git .

# Install the dependencies
RUN npm install

# Build the React app for production
RUN npm run build

# Use an official Nginx image to serve the app
FROM nginx:alpine

# Copy the build files from the previous stage to the Nginx public directory
COPY --from=build /app/build /usr/share/nginx/html

# Expose port 80 to the outside world
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]


docker build -t react-nginx-app .

docker run -p 80:80 react-nginx-app
