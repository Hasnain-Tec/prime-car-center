import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  final SessionController session;

  const SettingsScreen({
    super.key,
    required this.session,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _logoPicker = ImagePicker();

  late final TextEditingController name;
  late final TextEditingController address;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController license;
  late final TextEditingController currency;
  late final TextEditingController invoicePrefix;
  late final TextEditingController footer;

  late bool requirePhoto;
  late bool allowGallery;

  Uint8List? _selectedLogoBytes;
  String? _selectedLogoName;
  bool _logoBusy = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    final workshop = widget.session.workshop;

    name = TextEditingController(text: workshop.name);
    address = TextEditingController(text: workshop.address);
    phone = TextEditingController(text: workshop.phone);
    email = TextEditingController(text: workshop.email);
    license = TextEditingController(text: workshop.licenseNumber);
    currency = TextEditingController(text: workshop.currency);
    invoicePrefix = TextEditingController(text: workshop.invoicePrefix);
    footer = TextEditingController(text: workshop.invoiceFooter);

    requirePhoto = workshop.requireVehiclePhoto;
    allowGallery = workshop.allowGalleryUpload;
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
    license.dispose();
    currency.dispose();
    invoicePrefix.dispose();
    footer.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    if (saving || _logoBusy) {
      return;
    }

    setState(() {
      _logoBusy = true;
    });

    try {
      final file = await _logoPicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLogoBytes = bytes;
        _selectedLogoName = file.name;
      });
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _logoBusy = false;
        });
      }
    }
  }

  void _clearSelectedLogo() {
    if (saving) {
      return;
    }

    setState(() {
      _selectedLogoBytes = null;
      _selectedLogoName = null;
    });
  }

  Map<String, dynamic> get _jsonSettings => {
        'name': name.text.trim(),
        'address': address.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'license_number': license.text.trim(),
        'currency': currency.text.trim().toUpperCase(),
        'invoice_prefix': invoicePrefix.text.trim(),
        'invoice_footer': footer.text.trim(),
        'require_vehicle_photo': requirePhoto,
        'allow_gallery_upload': allowGallery,
      };

  Map<String, String> get _multipartSettings => {
        'name': name.text.trim(),
        'address': address.text.trim(),
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'license_number': license.text.trim(),
        'currency': currency.text.trim().toUpperCase(),
        'invoice_prefix': invoicePrefix.text.trim(),
        'invoice_footer': footer.text.trim(),
        'require_vehicle_photo': requirePhoto.toString(),
        'allow_gallery_upload': allowGallery.toString(),
      };

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      if (_selectedLogoBytes != null) {
        await widget.session.api.multipart(
          'workshop-settings/',
          method: 'PATCH',
          fields: _multipartSettings,
          fileBytes: _selectedLogoBytes,
          filename: _selectedLogoName ?? 'workshop-logo.jpg',
          fileField: 'logo',
        );
      } else {
        await widget.session.api.patch(
          'workshop-settings/',
          body: _jsonSettings,
        );
      }

      await widget.session.loadWorkshop();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLogoBytes = null;
        _selectedLogoName = null;
      });

      showSuccess(
        context,
        'Workshop settings saved successfully.',
      );
    } catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  String? _requiredValidator(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final emailValue = value?.trim() ?? '';

    if (emailValue.isEmpty) {
      return null;
    }

    if (!emailValue.contains('@') || !emailValue.contains('.')) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  Widget _fallbackLogo({
    double size = 104,
    double fontSize = 25,
  }) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PccColors.hazard,
        borderRadius: BorderRadius.circular(size * 0.19),
        border: Border.all(
          color: PccColors.charcoal,
          width: 2,
        ),
      ),
      child: Text(
        'PCC',
        style: TextStyle(
          color: PccColors.charcoal,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _logoImage({
    required double size,
  }) {
    if (_selectedLogoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          _selectedLogoBytes!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    final logoUrl = widget.session.workshop.logoUrl?.trim();

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            return _fallbackLogo(size: size);
          },
        ),
      );
    }

    return _fallbackLogo(size: size);
  }

  Widget _sectionIntro({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: PccColors.hazard.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: PccColors.hazardDark,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: PccColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: PccColors.inkSoft,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responsivePair({
    required Widget first,
    required Widget second,
    double breakpoint = 620,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              first,
              const SizedBox(height: 13),
              second,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 13),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PccColors.charcoal,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: PccColors.hazard,
            width: 5,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WORKSHOP SETTINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage company branding, web and mobile identity, business information, invoices, and job-entry rules.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          );

          final badge = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: PccColors.hazard.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: PccColors.hazard.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: PccColors.hazard,
                  size: 17,
                ),
                SizedBox(width: 6),
                Text(
                  'ADMIN SETTINGS',
                  style: TextStyle(
                    color: PccColors.hazard,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: 14),
                badge,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 18),
              badge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandingPanel() {
    final hasExistingLogo =
        widget.session.workshop.logoUrl?.trim().isNotEmpty == true;

    return PccPanel(
      title: 'Branding & Logo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionIntro(
            icon: Icons.auto_awesome_outlined,
            title: 'Company identity',
            description:
                'Upload one workshop logo here. It is shared by the web system and mobile app so your branding stays consistent everywhere.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;

              final preview = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PccColors.line),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PccColors.line),
                      ),
                      child: Center(
                        child: _logoBusy
                            ? const CircularProgressIndicator()
                            : _logoImage(size: 104),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedLogoBytes != null
                          ? 'New logo selected'
                          : hasExistingLogo
                              ? 'Current workshop logo'
                              : 'Default PCC logo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PccColors.charcoal,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_selectedLogoName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _selectedLogoName!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PccColors.inkSoft,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );

              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Workshop Logo',
                    style: TextStyle(
                      color: PccColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Recommended: PNG or JPG with a square or transparent background. The same saved logo will be used for web and mobile branding.',
                    style: TextStyle(
                      color: PccColors.inkSoft,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: saving || _logoBusy ? null : _pickLogo,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: PccColors.hazard,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      hasExistingLogo || _selectedLogoBytes != null
                          ? Icons.change_circle_outlined
                          : Icons.upload_file_outlined,
                    ),
                    label: Text(
                      hasExistingLogo || _selectedLogoBytes != null
                          ? 'CHANGE LOGO'
                          : 'UPLOAD LOGO',
                    ),
                  ),
                  if (_selectedLogoBytes != null) ...[
                    const SizedBox(height: 9),
                    OutlinedButton.icon(
                      onPressed: saving ? null : _clearSelectedLogo,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      icon: const Icon(Icons.undo),
                      label: const Text('CANCEL NEW LOGO'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: PccColors.hazard.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: PccColors.hazard.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: PccColors.hazardDark,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select the logo here, then press SAVE ALL SETTINGS at the bottom to upload it to the server.',
                            style: TextStyle(
                              color: PccColors.charcoal,
                              fontSize: 10.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    const SizedBox(height: 16),
                    controls,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 220,
                    child: preview,
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: controls),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _platformPreview({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool mobile,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: PccColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PccColors.hazard.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: PccColors.hazardDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PccColors.charcoal,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: PccColors.inkSoft,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? 12 : 10),
            decoration: BoxDecoration(
              color: PccColors.charcoal,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: mobile ? 38 : 42,
                  height: mobile ? 38 : 42,
                  child: _logoImage(size: mobile ? 38 : 42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.text.trim().isEmpty
                            ? 'PRIME CAR CENTER'
                            : name.text.trim().toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mobile ? 'Mobile Workshop App' : 'Workshop Web System',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFB9C2CC),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformPanel() {
    return PccPanel(
      title: 'Web & Mobile App',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionIntro(
            icon: Icons.devices_outlined,
            title: 'Platform branding',
            description:
                'The system is one Flutter project with separate responsive web and mobile experiences. The workshop name and logo are shared across both.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 680;

              final web = _platformPreview(
                icon: Icons.desktop_windows_outlined,
                title: 'Web Application',
                subtitle: 'Desktop and browser interface',
                mobile: false,
              );

              final app = _platformPreview(
                icon: Icons.phone_android_outlined,
                title: 'Mobile App',
                subtitle: 'Android / mobile interface',
                mobile: true,
              );

              if (compact) {
                return Column(
                  children: [
                    web,
                    const SizedBox(height: 12),
                    app,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: web),
                  const SizedBox(width: 12),
                  Expanded(child: app),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkshopInformationPanel() {
    return PccPanel(
      title: 'Business Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionIntro(
            icon: Icons.storefront_outlined,
            title: 'Workshop profile',
            description:
                'These details are used throughout the workshop system and can also appear on documents and invoices.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Workshop Name',
              hintText: 'Enter the workshop name',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            validator: (value) {
              return _requiredValidator(
                value,
                'Workshop name is required.',
              );
            },
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: address,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Business Address',
              hintText: 'Enter the complete workshop address',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 38),
                child: Icon(Icons.location_on_outlined),
              ),
            ),
          ),
          const SizedBox(height: 13),
          _responsivePair(
            first: TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. +971 50 123 4567',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            second: TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'e.g. workshop@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: _emailValidator,
            ),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: license,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Trade License / VAT / TRN',
              hintText: 'Enter the business registration number',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePanel() {
    return PccPanel(
      title: 'Invoice Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionIntro(
            icon: Icons.receipt_long_outlined,
            title: 'Invoice configuration',
            description:
                'Control the currency, invoice numbering prefix, and footer shown on workshop invoices.',
          ),
          const SizedBox(height: 18),
          _responsivePair(
            breakpoint: 540,
            first: TextFormField(
              controller: currency,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Currency',
                hintText: 'AED',
                counterText: '',
                prefixIcon: Icon(Icons.currency_exchange_outlined),
              ),
              validator: (value) {
                return _requiredValidator(
                  value,
                  'Currency is required.',
                );
              },
            ),
            second: TextFormField(
              controller: invoicePrefix,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Invoice Prefix',
                hintText: 'PCC-INV-',
                counterText: '',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              validator: (value) {
                return _requiredValidator(
                  value,
                  'Invoice prefix is required.',
                );
              },
            ),
          ),
          const SizedBox(height: 13),
          TextFormField(
            controller: footer,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Invoice Footer',
              hintText: 'e.g. Thank you for choosing our workshop.',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: value
            ? PccColors.hazard.withValues(alpha: 0.07)
            : const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              value ? PccColors.hazard.withValues(alpha: 0.45) : PccColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value
                  ? PccColors.hazard.withValues(alpha: 0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PccColors.line),
            ),
            child: Icon(
              icon,
              color: value ? PccColors.hazardDark : PccColors.inkSoft,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: PccColors.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: PccColors.inkSoft,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSettingsPanel() {
    return PccPanel(
      title: 'Job Photo Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionIntro(
            icon: Icons.photo_camera_outlined,
            title: 'Vehicle image rules',
            description:
                'Configure how check-in photos are handled when staff create workshop jobs.',
          ),
          const SizedBox(height: 18),
          _settingSwitch(
            icon: Icons.add_a_photo_outlined,
            title: 'Require a vehicle photo',
            description:
                'A job cannot be saved unless a vehicle image is captured or selected.',
            value: requirePhoto,
            onChanged: saving
                ? (_) {}
                : (value) {
                    setState(() {
                      requirePhoto = value;
                    });
                  },
          ),
          const SizedBox(height: 11),
          _settingSwitch(
            icon: Icons.photo_library_outlined,
            title: 'Allow gallery selection',
            description:
                'Users may choose an existing image from the mobile device or computer.',
            value: allowGallery,
            onChanged: saving
                ? (_) {}
                : (value) {
                    setState(() {
                      allowGallery = value;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildSavePanel() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PccColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final text = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save Changes',
                style: TextStyle(
                  color: PccColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Save business information, logo, invoice settings and job rules to the workshop server.',
                style: TextStyle(
                  color: PccColors.inkSoft,
                  fontSize: 10.8,
                  height: 1.4,
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: saving || _logoBusy ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(215, 52),
              backgroundColor: PccColors.hazard,
              foregroundColor: Colors.white,
            ),
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              saving ? 'SAVING...' : 'SAVE ALL SETTINGS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 15),
                button,
              ],
            );
          }

          return Row(
            children: [
              const Expanded(child: SizedBox()),
              Expanded(
                flex: 4,
                child: text,
              ),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    final pagePadding = screenWidth < 600
        ? 12.0
        : screenWidth < 1000
            ? 18.0
            : 24.0;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          pagePadding,
          16,
          pagePadding,
          32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1260),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPageHeader(),
                  const SizedBox(height: 16),
                  _buildBrandingPanel(),
                  const SizedBox(height: 16),
                  _buildPlatformPanel(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 980;

                      if (!desktop) {
                        return Column(
                          children: [
                            _buildWorkshopInformationPanel(),
                            const SizedBox(height: 16),
                            _buildInvoicePanel(),
                            const SizedBox(height: 16),
                            _buildPhotoSettingsPanel(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildWorkshopInformationPanel(),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildInvoicePanel(),
                                const SizedBox(height: 16),
                                _buildPhotoSettingsPanel(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSavePanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
