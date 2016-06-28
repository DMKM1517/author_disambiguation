# Author Disambiguation

Author disambiguation is an open issue in the world of academic digital libraries. As many problems arise when trying to identify if two different authors are the same and then group them, this issue has become more relevant inside the scientific community. This work illustrates a workflow that aims to solve this issue. By using the best of a relational database engine and data mining techniques implemented in R, we have implemented a workflow that correctly disambiguates authors present in papers retrieved from the Internet. To evaluate the results we perform a two-step-validation process inside the workflow, validating if two articles were written by the same author, and, if so, validating the authors grouped together as an unique disambiguated author. With the validations performed, the workflow implemented allows the process of identifying and disambiguating a new author.

The article ​**Ekaterina Bastrakova, Rodney Ledesma, & Jose Millan. (2016). Author Disambiguation. University Lumiere Lyon 2**​ can be found [here](Documents/AuthorDisambiguation_Bastrakova-Ledesma_Millan.pdf)

A web application was developed as the result of a Case Study Project based on this work. A virtual machine containing the self contained web application can be found **here**.

The application allows the user to fill the information of any article in order to disambiguate its signatures and find what other articles were written by the same author. In order to facilitate this process, the application offers the option to connect the users [Mendeley](http://mendeley.com/) account (by taking advantage of the [API offered by Mendeley](http://dev.mendeley.com/)), so he can select an specific article within his own library and import the information of the article automatically to the form.

After the user has filled the form with all the information of the article to process, the application then runs the author disambiguation workflow (as described in the work on which this application is based) and it presents the results containing the different articles written by the same authors of the processed article. The application also allows the user to give feedback over the results of the process so the application can improve its results over time.

The following video presents is a demo of the functionality of the application.

[![Automated Author Disambiguation](video_thumbnail.PNG)](https://youtu.be/DnTLwGgfwsg "Automated Author Disambiguation")

For more information please refer to our GitHub repository (with the link there). If you want to test the application, or you have any other question, please contact us to [dmkm.author.disambiguation@gmail.com](dmkm.author.disambiguation@gmail.com).

### Automated Author Disambiguation and Web Application Technical Documentation
Below you can find the technical documentation for this work:

 - [Database Installation & Description](db.md)
 - [Web Application Installation](ui.md)
 - [Training/Testing Script Descriptions](tt_scripts.md)
 - [Operational Script Descriptions](op_scripts.md)
