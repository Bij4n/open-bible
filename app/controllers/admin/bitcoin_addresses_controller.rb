class Admin::BitcoinAddressesController < ApplicationController
  before_action :ensure_admin

  def index
    @addresses = BitcoinAddress.order(created_at: :desc)
  end

  def new
    @address = BitcoinAddress.new
  end

  # One-step rotation: archive any current active row and create the new
  # row as active in a single transaction (BitcoinAddress.rotate_to!).
  # Validation failure rolls back the archive — the previous row stays
  # active, and we re-render the form with errors.
  def create
    attrs = bitcoin_address_params
    BitcoinAddress.rotate_to!(address: attrs[:address], notes: attrs[:notes].presence)
    redirect_to admin_bitcoin_addresses_path, notice: t("admin.bitcoin_addresses.rotated")
  rescue ActiveRecord::RecordInvalid => e
    @address = e.record
    render :new, status: :unprocessable_entity
  end

  private

  def bitcoin_address_params
    params.require(:bitcoin_address).permit(:address, :notes)
  end
end
