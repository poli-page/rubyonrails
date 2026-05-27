# frozen_string_literal: true

Rails.application.routes.draw do
  get "renderable_test/pdf_attachment", to: "renderable_test#pdf_attachment"
  get "renderable_test/preview",        to: "renderable_test#preview"
  get "renderable_test/redirect_doc",   to: "renderable_test#redirect_doc"
end
