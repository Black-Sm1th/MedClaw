#ifndef MAINVIEWCONTROLLER_H
#define MAINVIEWCONTROLLER_H

#include "CommonFunc.h"
#include <QObject>

class MainViewController : public QObject
{
    Q_OBJECT
    SINGLETON_CLASS(MainViewController)
public:
    Q_INVOKABLE void sendMessage();
};

#endif // MAINVIEWCONTROLLER_H
