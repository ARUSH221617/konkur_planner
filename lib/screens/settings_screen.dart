import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';

import '../providers/app_data_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'کاربر برنامه ریز کنکور';
  String? _userEmail;
  DateTime? _userBirthdate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    final userName = await appData.getUserName();
    final userEmail = await appData.getUserEmail();
    final userBirthdate = await appData.getUserBirthdate();
    setState(() {
      _userName = userName;
      _userEmail = userEmail;
      _userBirthdate = userBirthdate;
    });
  }

  Future<void> _editUserName() async {
    final newNameController = TextEditingController(text: _userName);
    final newName = await _showEditDialog(
      title: 'ویرایش نام کاربری',
      controller: newNameController,
    );

    if (newName != null && newName.isNotEmpty) {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      await appData.setUserName(newName);
      setState(() {
        _userName = newName;
      });
    }
  }

  Future<void> _editUserEmail() async {
    final newEmailController = TextEditingController(text: _userEmail);
    final newEmail = await _showEditDialog(
      title: 'ویرایش ایمیل',
      controller: newEmailController,
      keyboardType: TextInputType.emailAddress,
    );

    if (newEmail != null && newEmail.isNotEmpty) {
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      await appData.setUserEmail(newEmail);
      setState(() {
        _userEmail = newEmail;
      });
    }
  }

  Future<void> _selectBirthdate() async {
    Jalali? pickedDate = await showModalBottomSheet<Jalali>(
      context: context,
      builder: (context) {
        Jalali? tempPickedDate;
        return Container(
          height: 250,
          color: Theme.of(
            context,
          ).colorScheme.surface, // Use theme color for background
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  CupertinoButton(
                    child: Text(
                      'لغو',
                      style: TextStyle(
                        fontFamily: 'IRANSans', // Using available font
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  CupertinoButton(
                    child: Text(
                      'تایید',
                      style: TextStyle(
                        fontFamily: 'IRANSans', // Using available font
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onPressed: () {
                      debugPrint((tempPickedDate ?? Jalali.now()) as String?);
                      Navigator.of(context).pop(tempPickedDate ?? Jalali.now());
                    },
                  ),
                ],
              ),
              Divider(
                height: 0,
                thickness: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: PersianCupertinoDatePicker(
                  initialDateTime: _userBirthdate != null
                      ? Jalali.fromDateTime(_userBirthdate!)
                      : Jalali.now(),
                  mode: PersianCupertinoDatePickerMode
                      .date, // Changed to date mode
                  onDateTimeChanged: (Jalali dateTime) {
                    tempPickedDate = dateTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (pickedDate != null) {
      final gregorianDate = pickedDate.toDateTime();
      final appData = Provider.of<AppDataProvider>(context, listen: false);
      await appData.setUserBirthdate(gregorianDate);
      setState(() {
        _userBirthdate = gregorianDate;
      });
    }
  }

  Future<String?> _showEditDialog({
    required String title,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: const InputDecoration(hintText: 'مقدار را وارد کنید'),
        ),
        actions: [
          TextButton(
            child: const Text('لغو'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('ذخیره'),
            onPressed: () {
              Navigator.of(context).pop(controller.text);
            },
          ),
        ],
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: <Widget>[
          const ListTile(
            title: Text(
              'اطلاعات کاربر',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('نام کاربری'),
            subtitle: Text(_userName),
            onTap: _editUserName,
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('ایمیل'),
            subtitle: Text(_userEmail ?? 'Not set'),
            onTap: _editUserEmail,
          ),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text('تاریخ تولد'),
            subtitle: Text(
              _userBirthdate != null
                  ? (() {
                      final DateTime birthdate = _userBirthdate!;
                      final birthdateJalali = Jalali.fromDateTime(
                        birthdate,
                      ).formatter;
                      return '${birthdateJalali.yyyy}/${birthdateJalali.mm}/${birthdateJalali.dd} (سن: ${_calculateAge(birthdate)})';
                    })()
                  : 'تنظیم نشده',
            ),
            onTap: _selectBirthdate,
          ),
          const Divider(),
          const ListTile(
            title: Text(
              'عملیات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'حذف برنامه من',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تایید حذف'),
          content: const Text(
                        'آیا از حذف کل برنامه مطالعاتی خود مطمئن هستید؟ این عمل قابل بازگشت نیست.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('لغو'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Provider.of<AppDataProvider>(
                  context,
                  listen: false,
                ).deleteAllTasks();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('برنامه مطالعاتی حذف شد.')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
