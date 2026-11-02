// import 'package:flutter/material.dart';
// import 'package:first_app/app_colors.dart';
// import 'package:first_app/auth_api.dart';
// import 'package:first_app/api_client.dart';
// import 'package:first_app/token_storage.dart';
// import 'app_lock_service.dart';

// class AppLockScreen extends StatefulWidget {
//   final VoidCallback onUnlocked;

//   const AppLockScreen({super.key, required this.onUnlocked});

//   @override
//   State<AppLockScreen> createState() => _AppLockScreenState();
// }

// class _AppLockScreenState extends State<AppLockScreen> {
//   String _pinInput = '';
//   String? _fullName;
//   bool _isVerifying = false;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _loadName();
//   }

//   Future<void> _loadName() async {
//     final name = await LocalUserCache.getCachedName();
//     if (mounted) setState(() => _fullName = name);
//   }

//   void _onDigitPressed(String digit) {
//     if (_pinInput.length >= 6 || _isVerifying) return;
//     setState(() {
//       _pinInput += digit;
//       _errorMessage = null;
//     });
//     if (_pinInput.length == 6) _handleVerify();
//   }

//   void _onBackspace() {
//     if (_pinInput.isEmpty) return;
//     setState(() => _pinInput = _pinInput.substring(0, _pinInput.length - 1));
//   }

//   Future<void> _handleVerify() async {
//     setState(() => _isVerifying = true);
//     try {
//       final phone = await LocalUserCache.getCachedPhone();
//       if (phone == null) throw Exception('No cached session');

//       // Re-verifies the PIN against the backend — a real server-side
//       // check, not a local comparison, since the PIN's hash only ever
//       // lives on the backend.
//       final (access, refresh, fullName) = await AuthApi.login(
//         phoneNumber: phone,
//         pin: _pinInput,
//       );
//       await TokenStorage.saveTokens(access: access, refresh: refresh);
//       await LocalUserCache.saveUser(phone: phone, name: fullName);
//       await AppLockService.clearPausedState();

//       widget.onUnlocked();
//     } on ApiException catch (e) {
//       setState(() {
//         _errorMessage = e.message;
//         _pinInput = '';
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage =
//             'Couldn\'t verify. Check your connection and try again.';
//         _pinInput = '';
//       });
//     } finally {
//       if (mounted) setState(() => _isVerifying = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 40),
//               Container(
//                 width: 64,
//                 height: 64,
//                 decoration: const BoxDecoration(
//                   color: AppColors.tealTint,
//                   shape: BoxShape.circle,
//                 ),
//                 alignment: Alignment.center,
//                 child: const Icon(
//                   Icons.lock_outline_rounded,
//                   size: 28,
//                   color: AppColors.teal,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 _fullName != null
//                     ? 'Welcome back, ${_fullName!.split(' ').first}'
//                     : 'Enter your PIN',
//                 style: const TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w700,
//                   color: AppColors.textPrimary,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Enter your PIN to continue',
//                 style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
//               ),
//               const SizedBox(height: 28),
//               if (_errorMessage != null) ...[
//                 _buildErrorBanner(_errorMessage!),
//                 const SizedBox(height: 20),
//               ],
//               _buildPinDots(),
//               const Spacer(),
//               if (_isVerifying)
//                 const Center(
//                   child: CircularProgressIndicator(color: AppColors.teal),
//                 )
//               else
//                 _buildKeypad(),
//               const SizedBox(height: 12),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorBanner(String message) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       decoration: BoxDecoration(
//         color: const Color(0xFFFDECEC),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.error_outline, size: 18, color: Color(0xFFD64545)),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(
//                 fontSize: 14,
//                 color: Color(0xFFD64545),
//                 height: 1.4,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPinDots() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: List.generate(6, (index) {
//         final filled = index < _pinInput.length;
//         return Container(
//           margin: const EdgeInsets.symmetric(horizontal: 7),
//           width: 16,
//           height: 16,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: filled ? AppColors.teal : Colors.transparent,
//             border: Border.all(
//               color: filled ? AppColors.teal : AppColors.border,
//               width: 1.5,
//             ),
//           ),
//         );
//       }),
//     );
//   }

//   Widget _buildKeypad() {
//     final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];

//     return GridView.count(
//       shrinkWrap: true,
//       crossAxisCount: 3,
//       mainAxisSpacing: 8,
//       crossAxisSpacing: 8,
//       childAspectRatio: 1.6,
//       physics: const NeverScrollableScrollPhysics(),
//       children: keys.map((key) {
//         if (key.isEmpty) return const SizedBox.shrink();
//         if (key == 'back') {
//           return InkWell(
//             borderRadius: BorderRadius.circular(14),
//             onTap: _onBackspace,
//             child: const Center(
//               child: Icon(
//                 Icons.backspace_outlined,
//                 size: 22,
//                 color: AppColors.textSecondary,
//               ),
//             ),
//           );
//         }
//         return InkWell(
//           borderRadius: BorderRadius.circular(14),
//           onTap: () => _onDigitPressed(key),
//           child: Center(
//             child: Text(
//               key,
//               style: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.textPrimary,
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }
