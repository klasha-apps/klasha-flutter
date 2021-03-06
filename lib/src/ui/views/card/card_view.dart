import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:klasha_checkout/src/core/config/api_response.dart';
import 'package:klasha_checkout/src/core/core.dart';
import 'package:klasha_checkout/src/core/services/card/card_service_impl.dart';
import 'package:klasha_checkout/src/shared/shared.dart';
import 'package:klasha_checkout/src/ui/widgets/buttons/buttons.dart';
import 'package:klasha_checkout/src/ui/widgets/widgets.dart';

class CardCheckoutView extends StatefulWidget {
  const CardCheckoutView({
    Key key,
    this.onCheckoutResponse,
    this.amount,
    this.email,
    this.checkoutCurrency,
  }) : super(key: key);

  final OnCheckoutResponse<KlashaCheckoutResponse> onCheckoutResponse;
  final String email;
  final int amount;
  final CheckoutCurrency checkoutCurrency;

  @override
  _CardCheckoutViewState createState() => _CardCheckoutViewState();
}

class _CardCheckoutViewState extends State<CardCheckoutView> {
  PageController _pageController;
  int _currentPage = 0;
  String _cardNumber;
  String _cardExpiry;
  String _cardCvv;
  AddBankCardResponse _addBankCardResponse;
  AuthenticateBankCardResponse _authenticateBankCardResponse;
  String _transactionPin;
  String _otp;
  var _formKey = GlobalKey<FormState>();
  String _otpMessage = '';
  String _currencyName;
  String transactionReference;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _getCurrencyNameFromEnum();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _getCurrencyNameFromEnum() {
    switch (widget.checkoutCurrency) {
      case CheckoutCurrency.NGN:
        _currencyName = 'NGN';
        break;
      case CheckoutCurrency.KES:
        _currencyName = 'KES';
        break;
      case CheckoutCurrency.GHS:
        _currencyName = 'GHS';
        break;
    }
  }

  void _onPageChanged(int newPage) {
    setState(() {
      _currentPage = newPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15.0, 0.0, 15.0, 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.email,
            style: TextStyle(
              fontSize: 17,
              color: appColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            '$_currencyName ${widget.amount.toString()}',
            style: TextStyle(
              fontSize: 17,
              color: appColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              clipBehavior: Clip.none,
              physics: NeverScrollableScrollPhysics(),
              children: [
                _CardInputForm(
                  onCardNumberChanged: (val) => _cardNumber = val,
                  onCardExpiryChanged: (val) => _cardExpiry = val,
                  onCardCvvChanged: (val) => _cardCvv = val,
                  formKey: _formKey,
                ),
                _TransactionPinForm(
                  onTransactionPinChanged: (val) => _transactionPin = val,
                ),
                _OTPForm(
                  onOtpChanged: (val) => _otp = val,
                  message: _otpMessage,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          if (_currentPage == 0)
            PayWithKlashaButton(
              onPressed: () async {
                if (_formKey.currentState.validate()) {
                  transactionReference =  'klasha-add-bank-card-${DateTime.now().microsecondsSinceEpoch}';
                  String formattedCardNumber =
                      _cardNumber.replaceAll(RegExp(r"[^0-9]"), '');
                  String cardExpiryYear =
                      _cardExpiry.split(RegExp(r'(\/)')).last;
                  String cardExpiryMonth =
                      _cardExpiry.split(RegExp(r'(\/)')).first;
                  BankCardDetailsBody bankCardDetailsBody = BankCardDetailsBody(
                      cardNumber: formattedCardNumber,
                      expiryMonth: cardExpiryMonth,
                      expiryYear: cardExpiryYear,
                      cvv: _cardCvv,
                      currency: 'NGN',
                      amount: '1000',
                      rate: 1,
                      sourceCurrency: 'NGN',
                      rememberMe: false,
                      redirectUrl: 'https://dashboard.klasha.com/woocommerce',
                      phoneNumber: 'phone_number',
                      email: 'test@test.com',
                      fullName: 'Full Name',
                      txRef: transactionReference,
                  );

                  KlashaDialogs.showLoadingDialog(context);

                  ApiResponse<AddBankCardResponse> apiResponse =
                      await CardServiceImpl().addBankCard(bankCardDetailsBody);

                  Navigator.pop(context);

                  if (apiResponse.status) {
                    _addBankCardResponse = apiResponse.data;
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (apiResponse.status &&
                      apiResponse.data == null &&
                      apiResponse.message == 'Payment Successful') {
                    widget.onCheckoutResponse(
                      KlashaCheckoutResponse(
                        status: true,
                        message: 'Payment Successful',
                        transactionReference: transactionReference,
                      ),
                    );
                  } else {
                    KlashaDialogs.showStatusDialog(context, apiResponse.message);
                    // log('something went wrong, try again');
                  }
                }
              },
            ),
          if (_currentPage != 0)
            KlashaPrimaryButton(
              text: 'Continue',
              onPressed: () async {
                // authenticate payment
                if (_currentPage == 1) {
                  AuthenticateCardPaymentBody authenticateCardPaymentBody =
                      AuthenticateCardPaymentBody(
                    mode: 'pin',
                    pin: _transactionPin,
                    txRef: _addBankCardResponse.txRef,
                  );

                  KlashaDialogs.showLoadingDialog(context);

                  ApiResponse<AuthenticateBankCardResponse> apiResponse =
                      await CardServiceImpl()
                          .authenticateCardPayment(authenticateCardPaymentBody);

                  Navigator.pop(context);

                  if (apiResponse.status ||
                      apiResponse.data.status == 'pending') {
                    _otpMessage = apiResponse.data.message;
                    _authenticateBankCardResponse = apiResponse.data;
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (apiResponse.data.status != 'pending' &&
                      apiResponse.status) {
                    /// payment is successful
                    ///
                    widget.onCheckoutResponse(
                      KlashaCheckoutResponse(
                        status: true,
                        message: 'Payment Successful',
                        transactionReference: transactionReference,
                      ),
                    );
                  } else if (!apiResponse.status) {
                    KlashaDialogs.showStatusDialog(context, apiResponse.message);
                    // log('something went wrong, try again');
                  }
                }

                // validate payment
                if (_currentPage == 2) {
                  ValidateCardPaymentBody validateCardPaymentBody =
                      ValidateCardPaymentBody(
                    flwRef: _authenticateBankCardResponse.flwRef,
                    otp: _otp,
                    type: 'card',
                  );

                  KlashaDialogs.showLoadingDialog(context);

                  ApiResponse<ValidateBankCardResponse> apiResponse =
                      await CardServiceImpl()
                          .validateCardPayment(validateCardPaymentBody);

                  Navigator.pop(context);

                  if (apiResponse.status) {
                    widget.onCheckoutResponse(
                      KlashaCheckoutResponse(
                        status: true,
                        message: 'Payment Successful',
                        transactionReference: transactionReference,
                      ),
                    );
                  } else {
                    // KlashaDialogs.showStatusDialog(context, apiResponse.message);
                    widget.onCheckoutResponse(
                      KlashaCheckoutResponse(
                        status: false,
                        message: apiResponse.message ?? 'Payment Not Successful',
                        transactionReference: transactionReference,
                      ),
                    );
                    // log('something went wrong, try again');
                  }
                }
                // if (_currentPage != 2)
                //   _pageController.nextPage(
                //     duration: Duration(milliseconds: 300),
                //     curve: Curves.easeInOut,
                //   );
              },
            ),
          const SizedBox(
            height: 4,
          ),
        ],
      ),
    );
  }
}

class _CardInputForm extends StatelessWidget {
  const _CardInputForm({
    Key key,
    this.onCardNumberChanged,
    this.onCardExpiryChanged,
    this.onCardCvvChanged,
    this.formKey,
  }) : super(key: key);

  final Function(String) onCardNumberChanged;
  final Function(String) onCardExpiryChanged;
  final Function(String) onCardCvvChanged;
  final GlobalKey<FormState> formKey;

  bool _isFormValid() {
    return formKey.currentState.validate();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Card',
            style: TextStyle(
              fontSize: 14,
              color: appColors.subText,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          KlashaInputField(
            onChanged: onCardNumberChanged,
            hintText: '0000 0000 0000 0000',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'\d+')),
              LengthLimitingTextInputFormatter(19),
              CardNumberInputFormatter(),
            ],
            validator: KlashaUtils.validateCardNum,
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expiry',
                      style: TextStyle(
                        fontSize: 14,
                        color: appColors.subText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    KlashaInputField(
                      onChanged: onCardExpiryChanged,
                      hintText: 'MM / YY',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                        LengthLimitingTextInputFormatter(4),
                        CardMonthInputFormatter(),
                      ],
                      validator: KlashaUtils.validateDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 30,
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CVV',
                      style: TextStyle(
                        fontSize: 14,
                        color: appColors.subText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    KlashaInputField(
                      onChanged: onCardCvvChanged,
                      hintText: '123',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: KlashaUtils.validateCVC,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionPinForm extends StatelessWidget {
  const _TransactionPinForm({
    Key key,
    this.onTransactionPinChanged,
  }) : super(key: key);

  final Function(String) onTransactionPinChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Enter your transaction pin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: appColors.subText,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        KlashaInputField(
          onChanged: onTransactionPinChanged,
          hintText: 'Pin',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
      ],
    );
  }
}

class _OTPForm extends StatelessWidget {
  const _OTPForm({
    Key key,
    this.onOtpChanged,
    this.message,
  }) : super(key: key);

  final Function(String) onOtpChanged;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: appColors.subText,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          message,
          style: TextStyle(
            fontSize: 15,
            color: appColors.subText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(
          height: 20,
        ),
        KlashaInputField(
          onChanged: onOtpChanged,
          hintText: 'OTP',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'\d+')),
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      ],
    );
  }
}
