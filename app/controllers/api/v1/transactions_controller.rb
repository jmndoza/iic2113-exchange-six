class Api::V1::TransactionsController < Api::V1::BaseController
  before_action :set_transaction, only: [:show, :update, :destroy]

  # GET /transactions
  def index
    @transactions = Transaction.all
    render json: @transactions
  end

  # GET /transactions/{transaction id}
  def show
    render json: @transaction
  end

  # POST /transactions
  def create
    effective_transaction = validate_transaction(transaction_params)
    if effective_transaction
      TransactionMailer.with(transaction: @transaction).new_transaction_email.deliver_later
      render json: @transaction, status: :created
    else
      render json: @transaction.errors, status: :unprocessable_entity
    end
  end

  # PUT /transactions/{transaction id}
  def update
    if @transaction.update(transaction_params)
      render json: @transaction
    else
      render json: @transaction.errors, status: :unprocessable_entity
    end
  end

  # DELETE /transactions/{transaction id}
  def destroy
    @transaction.destroy
  end

  def validate_transaction(transaction_params)
    puts transaction_params
    coin = Coin.find(transaction_params[:coin_id])
    account = Account.find(transaction_params[:account_id])
    valid_transaction = true
    if transaction_params[:tipo] == "COMPRA"
      if coin.cantidad < transaction_params[:cantidad]
        valid_transaction = false
      elsif account.saldo_clp < coin.precio_compra * transaction_params[:cantidad] && !account.is_partner
        valid_transaction = false
      end
    elsif transaction_params[:tipo] == "VENTA" && coin.tipo == "BTF"
      if account.btfs < transaction_params[:cantidad]
        valid_transaction = false
      end
    elsif transaction_params[:tipo] == "VENTA" && coin.tipo == "BTH"
      if account.bths < transaction_params[:cantidad]
        valid_transaction = false
      end
    else
      valid_transaction = false
    end

    if valid_transaction
      return change_balances(account, coin, transaction_params[:tipo], transaction_params[:cantidad])
    else
      return false
    end
  end

  def change_balances(account, coin, transaction_type, amount)
    price = coin.precio_compra
    if transaction_type == "VENTA"
      amount = amount * -1
      price = coin.precio_venta
    end
    if coin.tipo == "BTF"
      account.btfs += amount
      account.saldo_clp -= amount * price
      account.save
      coin.cantidad -= amount
      coin.save
    else
      account.bths += amount
      account.saldo_clp -= amount * price
      account.save
      coin.cantidad -= amount
      coin.save
    end
    @transaction = Transaction.create(transaction_params)
    @transaction.valor_clp = price
    @transaction.save
    update_price(coin, transaction_type)
    return true
  end

  def update_price(coin, transaction_type)
    if transaction_type == "VENTA"
      coin.precio_venta *= 1.03
      coin.save
    else
      coin.precio_compra *= 1.03
      coin.save
    end
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:coin_id, :account_id, :cantidad, :tipo)
  end
end