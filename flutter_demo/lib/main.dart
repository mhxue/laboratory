import 'package:flutter/cupertino.dart';

void main() {
  runApp(const CupertinoDemoApp());
}

class CupertinoDemoApp extends StatelessWidget {
  const CupertinoDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Cupertino Widgets Demo',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: CupertinoDemoHomePage(),
    );
  }
}

class CupertinoDemoHomePage extends StatefulWidget {
  const CupertinoDemoHomePage({super.key});

  @override
  State createState() => _CupertinoDemoHomePageState();
}

class _CupertinoDemoHomePageState extends State<CupertinoDemoHomePage> {
  int _counter = 0;
  bool _switchValue = false;
  int _segmentedControlValue = 0;
  bool _checkboxValue = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Cupertino Widgets Demo'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Counter Section
                Text(
                  'Counter: $_counter',
                  style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: _incrementCounter,
                  child: const Text('Increment Counter'),
                ),
                
                const SizedBox(height: 30),
                Container(
                  height: 1,
                  color: CupertinoColors.systemGrey4,
                ),
                
                // Switch Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toggle Switch',
                      style: CupertinoTheme.of(context).textTheme.textStyle,
                    ),
                    CupertinoSwitch(
                      value: _switchValue,
                      onChanged: (bool value) {
                        setState(() {
                          _switchValue = value;
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Text(
                  'Switch is ${_switchValue ? 'ON' : 'OFF'}',
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 30),
                Container(
                  height: 1,
                  color: CupertinoColors.systemGrey4,
                ),
                
                // Segmented Control (Similar to Radio)
                Text(
                  'Choose a Category',
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                CupertinoSegmentedControl<int>(
                  children: const {
                    0: Text('Option 1'),
                    1: Text('Option 2'),
                    2: Text('Option 3'),
                  },
                  groupValue: _segmentedControlValue,
                  onValueChanged: (int value) {
                    setState(() {
                      _segmentedControlValue = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Selected Option: $_segmentedControlValue',
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 30),
                Container(
                  height: 1,
                  color: CupertinoColors.systemGrey4,
                ),
                
                // Checkbox-like Interaction (Using CupertinoButton)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agreement Checkbox',
                      style: CupertinoTheme.of(context).textTheme.textStyle,
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _checkboxValue = !_checkboxValue;
                        });
                      },
                      child: Icon(
                        _checkboxValue 
                          ? CupertinoIcons.check_mark_circled_solid 
                          : CupertinoIcons.circle,
                        color: _checkboxValue 
                          ? CupertinoColors.activeGreen 
                          : CupertinoColors.systemGrey,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Agreement Status: ${_checkboxValue ? 'Accepted' : 'Not Accepted'}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
