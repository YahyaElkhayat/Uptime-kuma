# Use the official Node.js 14 image as a parent image
FROM node:18

# Set the working directory in the container
WORKDIR /app

# Accept build arguments for npm configuration
ARG NPM_CONFIG_REGISTRY
ARG NPM_CONFIG_TIMEOUT
ARG NPM_CONFIG_FETCH_TIMEOUT
ARG NPM_CONFIG_FETCH_RETRIES

# Copy the current directory contents into the container at /app
COPY . .

# Install any dependencies
RUN npm install

# Assuming you're at the right directory context
# Backup the dist directory if it exists, and clear it
RUN if [ -d "./dist" ]; then cp -r ./dist ./dist-backup && rm -rf ./dist; fi

#Install dist
RUN npm run download-dist
EXPOSE 3001
CMD ["node", "server/server.js"]