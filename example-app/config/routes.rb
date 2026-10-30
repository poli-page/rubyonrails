# frozen_string_literal: true

# The routes every Poli Page SDK demo and integration example app exposes,
# plus the demo page at /.
Rails.application.routes.draw do
  root "demos#index"

  get    "/render/pdf",               to: "renders#pdf"
  get    "/render/stream",            to: "streams#stream"
  post   "/render/file",              to: "renders#render_file"
  post   "/documents",                to: "renders#document"
  get    "/documents/:id",            to: "documents#show",       constraints: { id: %r{[^/]+} }
  get    "/documents/:id/thumbnails", to: "documents#thumbnails", constraints: { id: %r{[^/]+} }
  get    "/documents/:id/preview",    to: "documents#preview",    constraints: { id: %r{[^/]+} }
  delete "/documents/:id",            to: "documents#destroy",    constraints: { id: %r{[^/]+} }
  get    "/errors/not-found",         to: "documents#not_found"

  # Rails default health-check (kept from the rails new scaffold).
  get "up" => "rails/health#show", as: :rails_health_check
end
