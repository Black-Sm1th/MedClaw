#include "mainviewcontroller.h"
#include <QDebug>
MainViewController::MainViewController(QObject* parent)
    : QObject(parent)
{


}

void MainViewController::sendMessage()
{
    qDebug() << "111111";
}
