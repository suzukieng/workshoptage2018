import { Injectable } from '@angular/core';

import { HttpClient, HttpHeaders } from '@angular/common/http';

@Injectable()
export class RestService {

  private restApiMultiUser = 'http://localhost:3000/api/';
  private restApiSingleUser = 'http://localhost:3001/api/';

  constructor(private httpClient: HttpClient) {
  }

  setupDemo() {
    return this.httpClient.post(this.restApiMultiUser + 'org.collectable.penguin._demoSetup', null, {withCredentials: true}).toPromise();
  }

  checkWallet() {
    return this.httpClient.get(this.restApiMultiUser + 'wallet', {withCredentials: true}).toPromise();
  }

  signUp(data) {
    const collector = {
      $class: 'org.collectable.penguin.Collector',
      collectorId: data.id,
      firstName: data.firstName,
      lastName: data.surname
    };

    return this.httpClient.post(this.restApiSingleUser + 'org.collectable.penguin.Collector', collector).toPromise()
      .then(() => {
        const identity = {
          participant: 'org.collectable.penguin.Collector#' + data.id,
          userID: data.id,
          options: {}
        };

        return this.httpClient.post(this.restApiSingleUser + 'system/identities/issue', identity, {responseType: 'blob'}).toPromise();
      })
      .then((cardData) => {
      console.log('CARD-DATA', cardData);
        const file = new File([cardData], 'myCard.card', {type: 'application/octet-stream', lastModified: Date.now()});

        const formData = new FormData();
        formData.append('card', file);

        const headers = new HttpHeaders();
        headers.set('Content-Type', 'multipart/form-data');
        return this.httpClient.post(this.restApiMultiUser + 'wallet/import', formData, {
          withCredentials: true,
          headers
        }).toPromise();
      });
  }

  getCurrentUser() {
    return this.httpClient.get(this.restApiMultiUser + 'system/ping', {withCredentials: true}).toPromise()
      .then((data) => {
        return data['participant'];
      });
  }

  getAllPenguins() {
    return this.httpClient.get(this.restApiMultiUser + 'org.collectable.penguin.Penguin', {withCredentials: true}).toPromise();
  }

  getAvailablePenguins() {
    return this.httpClient.get(this.restApiMultiUser + 'queries/availablePenguins', {withCredentials: true}).toPromise();
  }

  getMyPenguins() {
    return this.httpClient.get(this.restApiMultiUser + 'queries/myPenguins', {withCredentials: true}).toPromise();
  }

  buyPenguin(penguinId, currentUser) {
    const transactionDetails = {
      $class: 'org.collectable.penguin.Trade',
      penguin: 'resource:org.collectable.penguin.Penguin#' + penguinId,
      newOwner: currentUser
    };

    return this.httpClient.post(this.restApiMultiUser + 'org.collectable.penguin.Trade', transactionDetails, {withCredentials: true}).toPromise();
  }
}
