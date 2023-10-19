# Stage 1: Build the Next.js application
FROM node:18 AS builder

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json
COPY package.json ./

# Install dependencies
RUN npm install

# Copy the entire Next.js project to the container
COPY . .

# Build the Next.js application
RUN npm run build

# Stage 2: Create the production image
FROM node:18

# Set the working directory in the final container
WORKDIR /app

# Copy only the necessary files from the builder stage
COPY --from=builder /app/package.json /app/package-lock.json ./
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public

# Expose the application's port (change it if your app uses a different port)
EXPOSE 3000

# Start the Next.js application
CMD ["npm", "start"]
