class DonationsController < ApplicationController
  # All three actions are public — no auth, no admin gate. The page is
  # the donate-call surface; gating it would defeat the purpose.
  def show
    @address = BitcoinAddress.current
    @qr_svg  = build_qr_svg(@address.address) if @address
  end

  # Honeypot-tripped submissions silently redirect to the thank-you page
  # without persisting — bots see an indistinguishable success and the
  # report log stays clean of obvious junk. 404 when there's no active
  # address: the donate page itself shows an unavailable explainer for
  # the GET case, so a POST arriving here without a wallet is either
  # stale (admin rotated mid-session) or scripted, and 404 is the right
  # signal for both.
  def create_report
    return head :not_found unless BitcoinAddress.current

    if params[:website].present?
      redirect_to donate_thank_you_path
      return
    end

    DonationReport.create!(report_params)
    redirect_to donate_thank_you_path
  end

  def thanks
  end

  private

  def report_params
    params.fetch(:donation_report, {}).permit(:email, :message)
  end

  # BIP-21 URI without amount param so modern wallets pre-fill the send
  # screen on scan; older wallets that only parse bare addresses still
  # work because they treat the whole string as the address (the URI
  # scheme survives as a no-op prefix on those parsers).
  def build_qr_svg(address)
    payload = "bitcoin:#{address}"
    qr = RQRCode::QRCode.new(payload, level: :m)
    qr.as_svg(
      offset: 0,
      color: "currentColor",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true,
      use_path: true
    ).html_safe
  end
end
