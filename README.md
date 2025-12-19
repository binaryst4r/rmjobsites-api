# RMJobsites Backend API

Rails API backend for RMJobsites - a web application with ecommerce functionality using Square, service requests, and equipment rental requests.

## Tech Stack

- **Ruby**: 3.4.7
- **Rails**: 8.0.4 (API-only mode)
- **Database**: PostgreSQL
- **Authentication**: JWT (JSON Web Tokens)
- **Payment Processing**: Square API SDK
- **Web Server**: Puma

## Key Features

- JWT-based authentication
- User registration and login via email/password
- Square integration for ecommerce functionality
- API endpoints for services, equipment rentals, and requests
- CORS enabled for frontend integration

## Prerequisites

- Ruby 3.4.7
- PostgreSQL
- Bundler

## Environment Variables

Create a `.env` file in the backend directory with the following variables:

```bash
# Database
DATABASE_USER=your_postgres_username
DATABASE_PASSWORD=your_postgres_password
DATABASE_HOST=localhost

# Square API (for production/staging)
SQUARE_ACCESS_TOKEN=your_square_access_token
SQUARE_ENVIRONMENT=sandbox  # or production

# JWT Secret
JWT_SECRET=your_jwt_secret_key
```

## Installation

1. Install dependencies:
```bash
bundle install
```

2. Create and setup the database:
```bash
rails db:create
rails db:migrate
```

3. (Optional) Seed the database:
```bash
rails db:seed
```

## Running the Application

Start the Rails server:
```bash
rails server
```

The API will be available at `http://localhost:3000`

## Running Tests

Run the test suite with RSpec:
```bash
bundle exec rspec
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Create a new user account
- `POST /api/auth/login` - Login and receive JWT token

### Services
- API endpoints for managing service requests

### Equipment Rentals
- API endpoints for managing equipment rental requests

## Development Tools

- **RSpec**: Testing framework
- **Factory Bot**: Test fixtures
- **Faker**: Generate fake data for testing
- **Rubocop**: Ruby code linter
- **Brakeman**: Security vulnerability scanner
- **Dotenv**: Environment variable management

## Deployment

This application is configured for deployment using:
- **Kamal**: Docker-based deployment tool
- **Thruster**: HTTP asset caching and compression
- **Solid Queue**: Background job processing
- **Solid Cache**: Database-backed caching
- **Solid Cable**: WebSocket connections

To deploy:
```bash
kamal setup
kamal deploy
```

## Project Structure

```
backend/
├── app/
│   ├── controllers/    # API controllers
│   ├── models/         # ActiveRecord models
│   └── services/       # Business logic services
├── config/
│   ├── routes.rb       # API routes
│   └── database.yml    # Database configuration
├── db/
│   ├── migrate/        # Database migrations
│   └── schema.rb       # Current database schema
└── spec/               # RSpec tests
```

## Contributing

1. Write tests for new features
2. Follow Ruby style guide (enforced by Rubocop)
3. Run security checks with Brakeman before committing
4. Ensure all tests pass before submitting PRs
